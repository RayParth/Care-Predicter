import re
import json
import io
import os
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Form
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from database import get_db
from models import LabReport, User
from security import get_current_user
from config import settings
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


def extract_value(text: str, patterns: list) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            try:
                raw = match.group(1).replace(",", "").strip()
                val = float(raw)
                if 0 < val < 1000000:
                    return val
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(text: str) -> dict:
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


def ocr_image(image: Image.Image) -> str:
    processed = preprocess_image(image)
    best = ""
    for cfg in [r"--oem 3 --psm 6", r"--oem 3 --psm 4", r"--oem 3 --psm 3"]:
        try:
            text = pytesseract.image_to_string(processed, config=cfg)
            if len(text.strip()) > len(best.strip()):
                best = text
        except Exception:
            continue
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


async def extract_lab_data_with_gemini(text: str) -> dict:
    """Extract every explicit laboratory field from OCR text into dynamic JSON."""
    if not settings.GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    prompt = f"""
You are the structured-data extraction engine for a medical laboratory report.

Extract ALL information explicitly present in the OCR text below.

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
{{
  "patient": {{
    "name": null,
    "age": null,
    "sex": null
  }},
  "report": {{
    "lab_name": null,
    "report_date": null,
    "specimen": null
  }},
  "tests": {{}},
  "interpretation": [],
  "other_information": {{}}
}}

Each test value in "tests" must be an object like:
"test name": {{
  "display_name": "Original test name",
  "value": null,
  "unit": null,
  "reference_range": null,
  "qualitative_result": null,
  "flag": null
}}

OCR TEXT:
{text[:60000]}
"""

    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    response = await client.aio.models.generate_content(
        model=settings.GEMINI_MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.0,
            max_output_tokens=8192,
            response_mime_type="application/json",
        ),
    )

    raw = _clean_json_response(response.text or "")
    if not raw:
        raise ValueError("Gemini returned empty extraction output")

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Gemini returned invalid JSON: {exc}") from exc

    return _normalise_dynamic_data(parsed)


def _legacy_values_from_dynamic(dynamic_data: dict) -> dict:
    """Map known dynamic tests into old DB columns for backward compatibility."""
    tests = dynamic_data.get("tests", {})
    aliases = {
        "hemoglobin": "hemoglobin",
        "hb": "hemoglobin",
        "hgb": "hemoglobin",
        "rbc": "rbc",
        "wbc": "wbc",
        "total_wbc": "wbc",
        "platelets": "platelets",
        "platelet_count": "platelets",
        "plt": "platelets",
        "glucose": "glucose",
        "cholesterol": "cholesterol",
        "total_cholesterol": "cholesterol",
        "triglycerides": "triglycerides",
        "creatinine": "creatinine",
        "uric_acid": "uric_acid",
        "bilirubin": "bilirubin",
        "total_bilirubin": "bilirubin",
        "sgpt": "sgpt",
        "alt": "sgpt",
        "sgot": "sgot",
        "ast": "sgot",
        "hba1c": "hba1c",
        "tsh": "tsh",
        "vitamin_d": "vitamin_d",
        "vitamin_b12": "vitamin_b12",
        "sodium": "sodium",
        "potassium": "potassium",
        "calcium": "calcium",
        "ldl": "ldl",
        "hdl": "hdl",
        "mcv": "mcv",
        "mch": "mch",
        "pcv": "pcv",
        "hct": "pcv",
    }
    result = {}
    for key, item in tests.items():
        target = aliases.get(key)
        value = item.get("value") if isinstance(item, dict) else item
        if target and isinstance(value, (int, float)) and not isinstance(value, bool):
            result[target] = float(value)
    return result


# FIXED: user_id no longer has a default value of 1.
# Previously: user_id: int = 1 meant any request without a user_id
# silently saved lab data to user 1's account. Now it is required.
@router.post("/ocr/upload")
async def upload_lab_report(
        file: UploadFile = File(...),
        user_id: int = Form(...),       # FIXED: required, no default
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    # FIXED: previously any authenticated-or-not caller could pass any
    # user_id and their uploaded lab report would be saved under a stranger's
    # account. Now the form user_id must match the logged-in caller.
    if user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot upload a report for another user.")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")

    filename = file.filename or ""
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""

    if ext not in ["jpg", "jpeg", "png", "pdf"]:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported: {filename}. Use JPG, JPEG, PNG or PDF."
        )

    raw_bytes = await file.read()
    all_text = ""

    if ext == "pdf":
        try:
            import fitz
            doc = fitz.open(stream=raw_bytes, filetype="pdf")
            print(f"PDF pages: {len(doc)}")
            for i in range(len(doc)):
                page = doc[i]
                mat = fitz.Matrix(3.0, 3.0)
                pix = page.get_pixmap(matrix=mat)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                page_text = ocr_image(img)
                all_text += f"\n--- PAGE {i+1} ---\n{page_text}"
                print(f"Page {i+1}: {len(page_text)} chars")
        except ImportError:
            raise HTTPException(status_code=500, detail="Run: pip install PyMuPDF")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"PDF error: {str(e)}")
    else:
        try:
            image = Image.open(io.BytesIO(raw_bytes))
            all_text = ocr_image(image)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Image error: {str(e)}")

    print(f"Total OCR text: {len(all_text)} chars")
    print("--- OCR TEXT PREVIEW ---")
    print(all_text[:2000])
    print("--- END PREVIEW ---")

    if not all_text.strip():
        return JSONResponse({
            "status": "no_text",
            "extracted_values": {},
            "extracted_data": {
                "patient": {},
                "report": {},
                "tests": {},
                "interpretation": [],
                "other_information": {},
            },
            "values_found": 0,
            "raw_text": "",
        })

    # Primary extraction: Gemini turns arbitrary OCR content into structured JSON.
    # Fallback: the old regex parser keeps the upload path usable if Gemini is down.
    extraction_error = None
    try:
        extracted_data = await extract_lab_data_with_gemini(all_text)
        extraction_method = "gemini"
    except Exception as exc:
        extraction_error = str(exc)
        print(f"[OCR] Gemini extraction failed: {exc}")
        legacy = parse_lab_values(all_text)
        extracted_data = {
            "patient": {},
            "report": {},
            "tests": {
                k: {
                    "display_name": k.replace("_", " ").title(),
                    "value": v,
                    "unit": None,
                    "reference_range": None,
                    "qualitative_result": None,
                    "flag": None,
                }
                for k, v in legacy.items()
            },
            "interpretation": [],
            "other_information": {},
        }
        extraction_method = "regex_fallback"

    tests = extracted_data.get("tests", {})
    legacy_values = _legacy_values_from_dynamic(extracted_data)
    report_meta = extracted_data.get("report", {})

    print(f"[OCR] Extraction method: {extraction_method}")
    print(f"[OCR] Dynamic tests found: {len(tests)}")
    print(f"[OCR] Tests: {list(tests.keys())}")

    try:
        report = LabReport(
            user_id=user_id,
            lab_name=report_meta.get("lab_name") or filename,
            report_date=report_meta.get("report_date") or "",
            extracted_data=extracted_data,
            hemoglobin=legacy_values.get("hemoglobin"),
            rbc=legacy_values.get("rbc"),
            wbc=legacy_values.get("wbc"),
            platelets=legacy_values.get("platelets"),
            glucose=legacy_values.get("glucose"),
            cholesterol=legacy_values.get("cholesterol"),
            triglycerides=legacy_values.get("triglycerides"),
            creatinine=legacy_values.get("creatinine"),
            uric_acid=legacy_values.get("uric_acid"),
            bilirubin=legacy_values.get("bilirubin"),
            sgpt=legacy_values.get("sgpt"),
            sgot=legacy_values.get("sgot"),
            hba1c=legacy_values.get("hba1c"),
            tsh=legacy_values.get("tsh"),
            vitamin_d=legacy_values.get("vitamin_d"),
            vitamin_b12=legacy_values.get("vitamin_b12"),
            sodium=legacy_values.get("sodium"),
            potassium=legacy_values.get("potassium"),
            calcium=legacy_values.get("calcium"),
            ldl=legacy_values.get("ldl"),
            hdl=legacy_values.get("hdl"),
            mcv=legacy_values.get("mcv"),
            mch=legacy_values.get("mch"),
            pcv=legacy_values.get("pcv"),
            raw_text=all_text,
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        report_id = report.id
        print(f"[OCR] Saved to DB: report_id={report_id}")
    except Exception as exc:
        db.rollback()
        report_id = None
        print(f"[OCR] DB save error: {exc}")
        raise HTTPException(status_code=500, detail="Failed to save extracted lab report.")

    response = {
        "status": "success" if tests else "no_values",
        "filename": filename,
        "report_id": report_id,
        "extraction_method": extraction_method,
        "extracted_data": extracted_data,
        "extracted_values": legacy_values,
        "values_found": len(tests),
        "raw_text": all_text[:1000],
    }

    if extraction_error:
        response["extraction_warning"] = (
            "Gemini extraction was unavailable; legacy extraction was used."
        )

    return JSONResponse(response)

