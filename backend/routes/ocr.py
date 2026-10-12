import re
import json
import io
import os
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Form
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from database import get_db
from models import LabReport, User
from security import get_current_user
from config import settings
from gemini_util import is_model_gone, models_to_try
from google import genai
from google.genai import types

router = APIRouter()

# FIXED: Tesseract path is now platform-aware.
# Hardcoding C:\Program Files\... means OCR silently breaks on any Linux server
# (Railway, Render, AWS, etc.). Now it only sets the path explicitly on Windows.
if os.name == "nt":
    pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
# On Linux/Mac: tesseract must be installed system-wide (apt-get install tesseract-ocr)
# and pytesseract will find it automatically via PATH.


def preprocess_image(image: Image.Image) -> Image.Image:
    if image.mode != "RGB":
        image = image.convert("RGB")
    w, h = image.size
    if w < 1400:
        scale = 1400 / w
        image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    image = image.convert("L")
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)
    image = image.filter(ImageFilter.SHARPEN)
    return image


# Separator between a test name and its value. Besides punctuation/space it now
# also skips one short parenthesised unit/alias, e.g. "Total Cholesterol (mg/dL) 178"
# or "SGPT (ALT) 28".
_OLD_SEP = r"[\s:.\-|=*]+"
_NEW_SEP = r"(?:[\s:.\-|=*]|\([A-Za-z0-9/%^.\s]{1,14}\))+"
_RANGE_AFTER = re.compile(r"\s*(?:-|\u2013|to)\s*\d")
_NUM = re.compile(r"\d+\.?\d*")
_OLD_NUMCAP = r"(\d+\.?\d*)"
# also captures thousands separators: "11,200" (previously cut off at "11")
_NEW_NUMCAP = r"(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.?\d*)"


def normalise_ocr_text(text: str) -> str:
    """Fix the most common OCR damage before pattern matching."""
    # "13,2" -> "13.2"  (comma decimals); "1,200" (3 digits) is left alone.
    text = re.sub(r"(?<=\d),(?=\d{1,2}(?!\d))", ".", text)
    # "9O" / "O.9" -> digits, only when touching a digit.
    text = re.sub(r"(?<=\d)[Oo](?!\w)|(?<![\w])[Oo](?=\d)", "0", text)
    return text


def extract_value(text: str, patterns: list) -> float | None:
    for pattern in patterns:
        pattern = pattern.replace(_OLD_SEP, _NEW_SEP).replace(_OLD_NUMCAP, _NEW_NUMCAP)
        for match in re.finditer(pattern, text, re.IGNORECASE | re.MULTILINE):
            try:
                val = float(match.group(1).replace(",", "").strip())
            except (ValueError, AttributeError):
                continue
            # "Hemoglobin 12.0 - 15.0 g/dL 13.2": the first number is the start
            # of the reference range, not the result. Take the first number after it.
            if _RANGE_AFTER.match(text, match.end(1)):
                line_end = text.find("\n", match.end(1))
                line_end = len(text) if line_end == -1 else line_end
                tail = text[match.end(1):line_end]
                nums = _NUM.findall(re.sub(r"^\s*(?:-|\u2013|to)\s*\d+\.?\d*", "", tail))
                if not nums:
                    continue
                try:
                    val = float(nums[0])
                except ValueError:
                    continue
            if 0 < val < 1000000:
                return val
    return None


def parse_lab_values(text: str) -> dict:
    text = normalise_ocr_text(text)
    results = {}

    results["hemoglobin"] = extract_value(text, [
        r"\bHb\b[\s:.\-|=*]+(\d+\.?\d*)\s*gm",
        r"\bHGB\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Hh]aemoglobin[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Hh]emoglobin[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bHgb\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bHb\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["rbc"] = extract_value(text, [
        r"\bRBC\b[\s:.\-|=*]+(\d+\.?\d*)\s*mil",
        r"\bRBC\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Rr]ed\s*[Bb]lood\s*[Cc]ell[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Ee]rythrocyte[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["wbc"] = extract_value(text, [
        r"[Tt]otal\s*W\.?B\.?C\.?[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bWBC\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Ll]eucocyte[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bTLC\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Ww]hite\s*[Bb]lood[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["platelets"] = extract_value(text, [
        r"[Pp]latelets?\s*\([Ff]luorescent\)[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Pp]latelets?\s*\(IPF\)[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Pp]latelet\s*[Cc]ount[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bPLT\s*&?F?\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bPLT\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Pp]latelet[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["mcv"] = extract_value(text, [
        r"\bM\.?C\.?V\.?\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bMCV\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["mch"] = extract_value(text, [
        r"\bM\.?C\.?H\.?\b[\s:.\-|=*]+(\d+\.?\d*)\s*[Pp]g",
        r"\bMCH\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["glucose"] = extract_value(text, [
        r"[Gg]lucose\s*\([Ff]asting\)[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Gg]lucose\s*\([Rr]andom\)[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Gg]lucose[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bFBS\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bRBS\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Bb]lood\s*[Ss]ugar[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["cholesterol"] = extract_value(text, [
        r"[Tt]otal\s*[Cc]holesterol[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Cc]holesterol,\s*[Tt]otal[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Cc]holesterol[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["triglycerides"] = extract_value(text, [
        r"[Tt]riglycerides?[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bTG\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["creatinine"] = extract_value(text, [
        r"[Ss]erum\s*[Cc]reatinine[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Cc]reatinine[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bCREAT\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["uric_acid"] = extract_value(text, [
        r"[Uu]ric\s*[Aa]cid[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Ss]erum\s*[Uu]ric[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["bilirubin"] = extract_value(text, [
        r"[Tt]otal\s*[Bb]ilirubin[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Bb]ilirubin[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["sgpt"] = extract_value(text, [
        r"\bSGPT\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bALT\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["sgot"] = extract_value(text, [
        r"\bSGOT\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bAST\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["hba1c"] = extract_value(text, [
        r"[Hh][Bb][Aa]1[Cc][\s:.\-|=*]+(\d+\.?\d*)",
        r"[Gg]lycated\s*[Hh][ae]moglobin[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Aa]1[Cc][\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["tsh"] = extract_value(text, [
        r"\bTSH\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Tt]hyroid\s*[Ss]timulating[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["vitamin_d"] = extract_value(text, [
        r"[Vv]itamin\s*[Dd][\s:.\-|=*]+(\d+\.?\d*)",
        r"25[\s\-]*[Oo][Hh][\s\-]*[Dd][\s:.\-|=*]+(\d+\.?\d*)",
        r"[Vv]it\.?\s*[Dd][\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["vitamin_b12"] = extract_value(text, [
        r"[Vv]itamin\s*[Bb][\s\-]*12[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bB[\s\-]*12\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["sodium"] = extract_value(text, [
        r"[Ss]odium[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bNa\+?[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["potassium"] = extract_value(text, [
        r"[Pp]otassium[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bK\+?[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["ldl"] = extract_value(text, [
        r"\bLDL\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Ll]ow\s*[Dd]ensity[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["hdl"] = extract_value(text, [
        r"\bHDL\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"[Hh]igh\s*[Dd]ensity[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    results["pcv"] = extract_value(text, [
        r"\bP\.?C\.?V\.?\b[\s:.\-|=*]+(\d+\.?\d*)",
        r"\bHCT\b[\s:.\-|=*]+(\d+\.?\d*)",
    ])

    return {k: v for k, v in results.items() if v is not None}


def _row_like_lines(text: str) -> int:
    """Lines that contain both a word and a number: what a lab-table row looks like."""
    return sum(1 for ln in text.splitlines()
               if re.search(r"[A-Za-z]{3,}", ln) and re.search(r"\d", ln))


def ocr_image(image: Image.Image) -> str:
    """Run Tesseract in row-preserving modes and keep the most *useful* result.

    The previous version kept the LONGEST output. psm 3 pads output with blank
    lines and reads tables column by column, so it usually won and broke the
    name->value association. psm 6/4 keep table rows on one line.
    """
    processed = preprocess_image(image)
    best, best_score = "", (-1, -1)
    for cfg in (r"--oem 3 --psm 6", r"--oem 3 --psm 4", r"--oem 3 --psm 11"):
        try:
            text = pytesseract.image_to_string(processed, config=cfg)
        except Exception:
            continue
        score = (len(parse_lab_values(text)), _row_like_lines(text))
        if score > best_score:
            best, best_score = text, score
    return best


def _clean_json_response(text: str) -> str:
    """Remove common markdown wrappers around Gemini JSON output."""
    text = (text or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _normalise_test_key(name: str) -> str:
    """Create a stable JSON key without losing the original display name."""
    key = re.sub(r"[^a-zA-Z0-9]+", "_", (name or "").strip().lower()).strip("_")
    return key or "unknown_test"


def _normalise_dynamic_data(data: dict) -> dict:
    """Validate the minimum structure and normalise test keys."""
    if not isinstance(data, dict):
        raise ValueError("Gemini returned a non-object JSON response")

    patient = data.get("patient")
    report = data.get("report")
    tests = data.get("tests")
    interpretation = data.get("interpretation")
    other = data.get("other_information")

    if not isinstance(patient, dict):
        patient = {}
    if not isinstance(report, dict):
        report = {}
    if not isinstance(tests, dict):
        tests = {}
    if not isinstance(interpretation, list):
        interpretation = []
    if not isinstance(other, dict):
        other = {}

    normalised_tests = {}
    for original_name, raw_test in tests.items():
        key = _normalise_test_key(str(original_name))
        if isinstance(raw_test, dict):
            item = {
                "display_name": raw_test.get("display_name") or str(original_name),
                "value": raw_test.get("value"),
                "unit": raw_test.get("unit"),
                "reference_range": raw_test.get("reference_range"),
                "qualitative_result": raw_test.get("qualitative_result"),
                "flag": raw_test.get("flag"),
            }
        else:
            # Keep unexpected but valid values instead of silently dropping them.
            item = {
                "display_name": str(original_name),
                "value": raw_test,
                "unit": None,
                "reference_range": None,
                "qualitative_result": None,
                "flag": None,
            }
        normalised_tests[key] = item

    return {
        "patient": patient,
        "report": report,
        "tests": normalised_tests,
        "interpretation": [str(x) for x in interpretation if x is not None],
        "other_information": other,
    }


LAB_RULES = """
You are the structured-data extraction engine for a medical laboratory report.

Extract ALL information explicitly present in the laboratory report provided.

STRICT RULES:
- Extract every laboratory test/parameter you can identify.
- Do NOT use a predefined test list.
- If a new test appears, create a new key automatically.
- Never invent, estimate, infer, or calculate a missing laboratory value.
- Preserve numeric values exactly as reported when possible.
- Preserve units exactly or in a clear standard form.
- Preserve reference ranges when present.
- Preserve qualitative results such as Positive, Negative, Reactive,
  Non-reactive, Equivocal, Normal, Abnormal, Present and Absent.
- Preserve abnormal flags when explicitly present or clearly stated by the report.
- Preserve laboratory interpretation/comments.
- Extract patient name, age, sex, lab name, report date and specimen when present.
- Do not provide a diagnosis or medical advice.
- OCR may contain spelling errors. Correct obvious OCR corruption only when the
  intended test name/value is unambiguous from surrounding text.
- If the same test appears multiple times, keep the clinically relevant reported
  result and do not manufacture an average.
- Return JSON only. No markdown. No explanation outside JSON.

Return exactly this top-level shape:
{
  "patient": {
    "name": null,
    "age": null,
    "sex": null
  },
  "report": {
    "lab_name": null,
    "report_date": null,
    "specimen": null
  },
  "tests": {},
  "interpretation": [],
  "other_information": {}
}

Each test value in "tests" must be an object like:
"test name": {
  "display_name": "Original test name",
  "value": null,
  "unit": null,
  "reference_range": null,
  "qualitative_result": null,
  "flag": null
}
"""

_MIME = {"pdf": "application/pdf", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}


async def _run_gemini_extraction(contents) -> dict:
    """Call Gemini with model fallback (2.5-flash is being retired) and parse JSON."""
    if not settings.GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    last_exc = None
    for model in models_to_try():
        try:
            response = await client.aio.models.generate_content(
                model=model,
                contents=contents,
                config=types.GenerateContentConfig(
                    temperature=0.0,
                    max_output_tokens=16384,  # long panels (LFT+KFT+CBC) overflowed 8192
                    response_mime_type="application/json",
                ),
            )
            raw = _clean_json_response(response.text or "")
            if not raw:
                raise ValueError("Gemini returned empty extraction output")
            return _normalise_dynamic_data(json.loads(raw))
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
            if is_model_gone(exc):
                continue
            break
    raise RuntimeError(f"Gemini extraction failed: {last_exc}")


async def extract_lab_data_from_file_with_gemini(raw_bytes: bytes, ext: str) -> dict:
    """PRIMARY path: let Gemini read the image/PDF itself. It sees the table
    layout, so each value stays attached to the right row. This is what fixes
    the accuracy problem; Tesseract only linearises text."""
    prompt = (
        LAB_RULES
        + "\nThe laboratory report is the attached file. Read tables row by row: "
        "each result belongs to the test name in the SAME row. Do not take a "
        "value from the reference-range column as the result."
    )
    part = types.Part.from_bytes(data=raw_bytes, mime_type=_MIME[ext])
    return await _run_gemini_extraction([part, prompt])


async def extract_lab_data_with_gemini(text: str) -> dict:
    """SECOND path: structure Tesseract text (used if the file path fails)."""
    return await _run_gemini_extraction(LAB_RULES + "\nOCR TEXT:\n" + text[:60000])


# Ordered rules: (target column, must match, must NOT match). Matched against the
# lab's own test name, lower-cased. The old code did an exact dictionary lookup
# on the normalised name, so "Haemoglobin", "SGPT (ALT)", "Serum Creatinine",
# "LDL Cholesterol" ... never reached the columns the organ map reads.
_LEGACY_RULES: list[tuple[str, str, str]] = [
    ("hba1c",         r"hba1c|\ba1c\b|glyc(ated|osylated)",                       r""),
    ("mchc_skip",     r"\bmchc\b|conc(entration)?\b.*h(a?e)?moglobin",              r""),  # sink: not stored
    ("mch",           r"\bmch\b|mean corpuscular h(a?e)?moglobin",                  r"conc|mchc"),
    ("mcv",           r"\bmcv\b|mean corpuscular volume",                          r""),
    ("pcv",           r"\bpcv\b|h(a?e)?matocrit|\bhct\b|packed cell",              r""),
    ("hemoglobin",    r"h(a?e)?moglobin|\bhgb\b|\bhb\b",                           r"a1c|glyc|corpuscular|mch"),
    ("rbc",           r"\brbc\b|red (blood )?cell|erythrocyte",                    r"distribution|rdw|width|volume|mean|hematocrit"),
    ("wbc",           r"\bwbc\b|\btlc\b|leu?kocyte|leucocyte|white (blood )?cell", r"differential|%|percent"),
    ("platelets",     r"platelet|\bplt\b",                                         r"mpv|pdw|distribution|mean|crit|volume|large"),
    ("hdl",           r"\bhdl\b",                                                  r"ratio|non|/"),
    ("ldl",           r"\bldl\b",                                                  r"vldl|ratio|/"),
    ("cholesterol",   r"cholesterol",                                               r"hdl|ldl|vldl|non[- ]?hdl|ratio"),
    ("triglycerides", r"triglycerid",                                               r""),
    ("glucose",       r"glucose|blood sugar|\bfbs\b|\bfbg\b|\brbs\b",           r"urine|post|\bpp\b|\bppbs\b|2 ?h|after|tolerance|hba1c"),
    ("creatinine",    r"creatinine",                                                r"clearance|ratio|urine|egfr|/"),
    ("uric_acid",     r"uric acid|\burate\b",                                       r"urine"),
    ("bilirubin",     r"bilirubin",                                                 r"direct|indirect|conjugated|unconjugated|urine"),
    ("sgpt",          r"\bsgpt\b|\balt\b|alanine",                                 r""),
    ("sgot",          r"\bsgot\b|\bast\b|aspartate",                               r""),
    ("tsh",           r"\btsh\b|thyroid stimulating",                               r""),
    ("vitamin_d",     r"vitamin ?d|25 ?-? ?(oh|hydroxy)",                            r""),
    ("vitamin_b12",   r"b ?-?12\b|cobalamin",                                        r""),
    ("sodium",        r"\bsodium\b|\bna\b",                                        r"urine"),
    ("potassium",     r"\bpotassium\b|\bk\b",                                      r"urine"),
    ("calcium",       r"\bcalcium\b",                                               r"urine|ionized|ionised"),
]
_LEGACY_COMPILED = [
    (t, re.compile(m, re.I), re.compile(x, re.I) if x else None)
    for t, m, x in _LEGACY_RULES
]


def _legacy_target(name: str) -> str | None:
    n = re.sub(r"[^a-z0-9%/]+", " ", (name or "").lower()).strip()
    for target, must, must_not in _LEGACY_COMPILED:
        if must.search(n) and not (must_not and must_not.search(n)):
            return None if target.endswith("_skip") else target
    return None


def _as_number(value):
    """Accept 13.2 and "13.2" and "1,200"; reject "<0.5", "Nil", True."""
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        v = value.strip().replace(",", "")
        if re.fullmatch(r"\d+(\.\d+)?", v):
            return float(v)
    return None


def _legacy_values_from_dynamic(dynamic_data: dict) -> dict:
    """Map dynamic tests onto the fixed DB columns the app's organ map and
    dashboard read. First match per column wins (e.g. fasting before others)."""
    result: dict = {}
    for key, item in dynamic_data.get("tests", {}).items():
        name = (item.get("display_name") if isinstance(item, dict) else None) or key
        target = _legacy_target(name) or _legacy_target(key)
        value = _as_number(item.get("value") if isinstance(item, dict) else item)
        if target and value is not None and target not in result:
            result[target] = value
    return result


MAX_UPLOAD_BYTES = 15 * 1024 * 1024
MAX_PDF_PAGES = 8


def _looks_like(ext: str, data: bytes) -> bool:
    """Check magic bytes so a renamed .exe can't ride in as .png."""
    if ext == "pdf":
        return data[:5] == b"%PDF-"
    if ext == "png":
        return data[:8] == b"\x89PNG\r\n\x1a\n"
    return data[:3] == b"\xff\xd8\xff"  # jpg / jpeg


def _tesseract_text(ext: str, raw_bytes: bytes) -> str:
    """Blocking CPU work: always call through run_in_threadpool."""
    if ext != "pdf":
        return ocr_image(Image.open(io.BytesIO(raw_bytes)))
    import fitz
    doc = fitz.open(stream=raw_bytes, filetype="pdf")
    if len(doc) > MAX_PDF_PAGES:
        raise ValueError(f"PDF has {len(doc)} pages; limit is {MAX_PDF_PAGES}.")
    out = ""
    for i in range(len(doc)):
        pix = doc[i].get_pixmap(matrix=fitz.Matrix(2.5, 2.5))
        out += f"\n--- PAGE {i+1} ---\n" + ocr_image(Image.open(io.BytesIO(pix.tobytes("png"))))
    return out


def _empty_data() -> dict:
    return {"patient": {}, "report": {}, "tests": {}, "interpretation": [], "other_information": {}}


@router.post("/ocr/upload")
async def upload_lab_report(
        file: UploadFile = File(...),
        user_id: int = Form(...),
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    if user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot upload a report for another user.")

    filename = file.filename or ""
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    if ext not in _MIME:
        raise HTTPException(status_code=400, detail=f"Unsupported: {filename}. Use JPG, PNG or PDF.")

    raw_bytes = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 15 MB).")
    if not _looks_like(ext, raw_bytes):
        raise HTTPException(status_code=400, detail="File content does not match its extension.")

    all_text = ""
    extracted_data = None
    method = None
    warnings: list[str] = []

    # 1) Gemini reads the file directly (best accuracy, keeps table rows intact)
    try:
        extracted_data = await extract_lab_data_from_file_with_gemini(raw_bytes, ext)
        method = "gemini_vision"
    except Exception as exc:  # noqa: BLE001
        warnings.append("Direct AI reading was unavailable; used OCR instead.")
        print(f"[OCR] vision path failed: {exc}")

    # 2) Tesseract (in a worker thread so the API stays responsive) -> Gemini text
    if extracted_data is None:
        try:
            all_text = await run_in_threadpool(_tesseract_text, ext, raw_bytes)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=400, detail=f"Could not read file: {exc}")

        if not all_text.strip():
            return JSONResponse({"status": "no_text", "extracted_values": {},
                                 "extracted_data": _empty_data(), "values_found": 0, "raw_text": ""})
        try:
            extracted_data = await extract_lab_data_with_gemini(all_text)
            method = "tesseract+gemini"
        except Exception as exc:  # noqa: BLE001
            print(f"[OCR] text path failed: {exc}")
            # 3) last resort: regex
            legacy = parse_lab_values(all_text)
            extracted_data = _empty_data()
            extracted_data["tests"] = {
                k: {"display_name": k.replace("_", " ").title(), "value": v, "unit": None,
                    "reference_range": None, "qualitative_result": None, "flag": None}
                for k, v in legacy.items()
            }
            method = "regex_fallback"
            warnings.append("AI extraction unavailable; only basic values were read. Please verify.")

    tests = extracted_data.get("tests", {})
    legacy_values = _legacy_values_from_dynamic(extracted_data)
    report_meta = extracted_data.get("report", {})

    # Don't store empty junk reports.
    if not tests:
        return JSONResponse({"status": "no_values", "filename": filename, "report_id": None,
                             "extraction_method": method, "extracted_data": extracted_data,
                             "extracted_values": {}, "values_found": 0, "raw_text": all_text[:1000]})

    try:
        report = LabReport(
            user_id=user_id,
            lab_name=report_meta.get("lab_name") or filename,
            report_date=report_meta.get("report_date") or "",
            extracted_data=extracted_data,
            raw_text=all_text,
            **{k: legacy_values.get(k) for k in (
                "hemoglobin", "rbc", "wbc", "platelets", "glucose", "cholesterol",
                "triglycerides", "creatinine", "uric_acid", "bilirubin", "sgpt", "sgot",
                "hba1c", "tsh", "vitamin_d", "vitamin_b12", "sodium", "potassium",
                "calcium", "ldl", "hdl", "mcv", "mch", "pcv")},
        )
        db.add(report)
        db.commit()
        db.refresh(report)
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        print(f"[OCR] DB save error: {exc}")
        raise HTTPException(status_code=500, detail="Failed to save extracted lab report.")

    response = {
        "status": "success",
        "filename": filename,
        "report_id": report.id,
        "extraction_method": method,
        "extracted_data": extracted_data,
        "extracted_values": legacy_values,
        "values_found": len(tests),
        "raw_text": all_text[:1000],
    }
    if warnings:
        response["extraction_warning"] = " ".join(warnings)
    return JSONResponse(response)
