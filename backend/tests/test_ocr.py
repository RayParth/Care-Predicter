import io
import shutil
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFont

from routes import ocr
from routes.ocr import parse_lab_values
from security import get_current_user
from database import get_db


# ---------------- regex parser regressions ----------------
@pytest.mark.parametrize("line,expected", [
    ("Hemoglobin   12.0 - 15.0 g/dL    13.2", {"hemoglobin": 13.2}),   # range first
    ("Hemoglobin 13,2 g/dL", {"hemoglobin": 13.2}),                     # decimal comma
    ("Total Cholesterol (mg/dL) 178", {"cholesterol": 178.0}),          # unit in brackets
    ("SGPT (ALT)  28 U/L", {"sgpt": 28.0}),                             # alias in brackets
    ("Glucose (Fasting) 9O mg/dL", {"glucose": 90.0}),                    # O -> 0
    ("Glucose (Fasting) 94 mg/dL", {"glucose": 94.0}),                  # still works
    ("Creatinine 0.9 mg/dL", {"creatinine": 0.9}),
    ("Hemoglobin 13.2 g/dL 12.0 - 15.0", {"hemoglobin": 13.2}),         # value before range
])
def test_parser_cases(line, expected):
    assert parse_lab_values(line) == expected


def test_thousands_separator_not_mangled():
    assert parse_lab_values("WBC 11,200 /uL")["wbc"] == 11200.0


# ---------------- tesseract mode selection ----------------
def _table_image():
    img = Image.new("RGB", (1200, 520), "white")
    d = ImageDraw.Draw(img)
    f = None
    for path in (r"C:\Windows\Fonts\arial.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                 "/Library/Fonts/Arial.ttf"):
        try:
            f = ImageFont.truetype(path, 26)
            break
        except OSError:
            continue
    if f is None:
        pytest.skip("no TrueType font found")
    rows = [("TEST", "RESULT", "UNIT", "REFERENCE RANGE"), ("Hemoglobin", "13.2", "g/dL", "12.0 - 15.0"),
            ("Total Cholesterol", "178", "mg/dL", "< 200"), ("Glucose (Fasting)", "94", "mg/dL", "70 - 100"),
            ("Creatinine", "0.9", "mg/dL", "0.7 - 1.3"), ("SGPT (ALT)", "28", "U/L", "< 45")]
    for i, row in enumerate(rows):
        for x, t in zip((30, 380, 560, 760), row):
            d.text((x, 30 + i * 70), t, fill="black", font=f)
    return img


@pytest.mark.skipif(shutil.which("tesseract") is None, reason="tesseract not installed")
def test_table_rows_survive_ocr():
    vals = parse_lab_values(ocr.ocr_image(_table_image()))
    # Before the fix this dict was EMPTY (psm 3 column-wise text won on length).
    assert vals.get("hemoglobin") == 13.2
    assert vals.get("cholesterol") == 178.0
    assert vals.get("glucose") == 94.0
    assert vals.get("creatinine") == 0.9
    assert vals.get("sgpt") == 28.0


# ---------------- endpoint behaviour ----------------
class U:
    id = 7


@pytest.fixture()
def client():
    app = FastAPI()
    app.include_router(ocr.router)
    app.dependency_overrides[get_current_user] = lambda: U()
    app.dependency_overrides[get_db] = lambda: MagicMock()
    return TestClient(app)


def png_bytes():
    b = io.BytesIO()
    _table_image().save(b, "PNG")
    return b.getvalue()


GOOD = {"patient": {}, "report": {"lab_name": "X Lab", "report_date": "2026-03-14"},
        "tests": {"hemoglobin": {"display_name": "Hemoglobin", "value": 13.2, "unit": "g/dL",
                                 "reference_range": "12-15", "qualitative_result": None, "flag": None}},
        "interpretation": [], "other_information": {}}


def post(client, data, name="r.png", uid=7):
    return client.post("/ocr/upload", files={"file": (name, data, "application/octet-stream")}, data={"user_id": str(uid)})


def test_vision_path_is_primary(client, monkeypatch):
    async def vision(raw, ext): return GOOD

    async def never(*a, **k): raise AssertionError("tesseract must not run")
    monkeypatch.setattr(ocr, "extract_lab_data_from_file_with_gemini", vision)
    monkeypatch.setattr(ocr, "_tesseract_text", never)
    r = post(client, png_bytes())
    assert r.status_code == 200 and r.json()["extraction_method"] == "gemini_vision"
    assert r.json()["extracted_values"] == {"hemoglobin": 13.2}


@pytest.mark.skipif(shutil.which("tesseract") is None, reason="tesseract not installed")
def test_falls_back_to_tesseract_then_regex(client, monkeypatch):
    async def fail(*a, **k): raise RuntimeError("gemini down")
    monkeypatch.setattr(ocr, "extract_lab_data_from_file_with_gemini", fail)
    monkeypatch.setattr(ocr, "extract_lab_data_with_gemini", fail)
    r = post(client, png_bytes())
    j = r.json()
    assert j["extraction_method"] == "regex_fallback"
    assert j["extracted_values"].get("glucose") == 94.0
    assert "verify" in j["extraction_warning"].lower()


def test_cannot_upload_for_someone_else(client):
    assert post(client, png_bytes(), uid=99).status_code == 403


def test_extension_mismatch_rejected(client):
    assert post(client, b"MZ\x90\x00 not an image", name="evil.png").status_code == 400


def test_bad_extension_rejected(client):
    assert post(client, png_bytes(), name="x.exe").status_code == 400


def test_oversize_rejected(client, monkeypatch):
    monkeypatch.setattr(ocr, "MAX_UPLOAD_BYTES", 1000)
    assert post(client, png_bytes()).status_code == 413


def test_empty_result_is_not_saved(client, monkeypatch):
    async def empty(raw, ext): return ocr._empty_data()
    monkeypatch.setattr(ocr, "extract_lab_data_from_file_with_gemini", empty)
    r = post(client, png_bytes())
    assert r.json()["status"] == "no_values" and r.json()["report_id"] is None
