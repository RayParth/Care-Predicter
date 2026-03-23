# backend/routes_ocr.py

import re
import io
import pytesseract
from PIL import Image
from fastapi import APIRouter, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from fastapi import Depends
from database import get_db
from models import LabReport

router = APIRouter()

# ─── Tesseract path (Windows) ───────────────────────────────────────────
# Uncomment and set the correct path if Tesseract is not in your PATH
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


# ─── Value extraction helpers ───────────────────────────────────────────

def extract_value(text: str, patterns: list[str]) -> float | None:
    """Try each regex pattern, return first numeric match found."""
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(",", ""))
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(raw_text: str) -> dict:
    """
    Extract medical values from raw OCR text.
    Handles varied Indian lab report formats.
    """
    text = raw_text

    values = {}

    # ── Glucose ─────────────────────────────────────────────────────────
    values["glucose"] = extract_value(text, [
        r"glucose[\s:.\-–|]+(\d+\.?\d*)",
        r"blood sugar[\s:.\-–|]+(\d+\.?\d*)",
        r"fasting[\s\w]*[\s:.\-–|]+(\d+\.?\d*)\s*mg",
        r"glu[\s:.\-–|]+(\d+\.?\d*)",
        r"rbs[\s:.\-–|]+(\d+\.?\d*)",
        r"fbs[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Hemoglobin ───────────────────────────────────────────────────────
    values["hemoglobin"] = extract_value(text, [
        r"h[ae]moglobin[\s:.\-–|]+(\d+\.?\d*)",
        r"\bhgb\b[\s:.\-–|]+(\d+\.?\d*)",
        r"\bhb\b[\s:.\-–|]+(\d+\.?\d*)",
        r"haemoglobin[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Cholesterol ──────────────────────────────────────────────────────
    values["cholesterol"] = extract_value(text, [
        r"total\s*cholesterol[\s:.\-–|]+(\d+\.?\d*)",
        r"cholesterol[\s:.\-–|]+(\d+\.?\d*)",
        r"chol[\s:.\-–|]+(\d+\.?\d*)",
        r"tc[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Triglycerides ────────────────────────────────────────────────────
    values["triglycerides"] = extract_value(text, [
        r"triglycerides?[\s:.\-–|]+(\d+\.?\d*)",
        r"tg[\s:.\-–|]+(\d+\.?\d*)",
        r"trigs?[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Creatinine ───────────────────────────────────────────────────────
    values["creatinine"] = extract_value(text, [
        r"creatinine[\s:.\-–|]+(\d+\.?\d*)",
        r"creat[\s:.\-–|]+(\d+\.?\d*)",
        r"s\.?\s*creatinine[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── WBC ──────────────────────────────────────────────────────────────
    values["wbc"] = extract_value(text, [
        r"wbc[\s:.\-–|]+(\d+\.?\d*)",
        r"white blood cell[\s:.\-–|]+(\d+\.?\d*)",
        r"total\s*wbc[\s:.\-–|]+(\d+\.?\d*)",
        r"leucocytes[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Platelets ────────────────────────────────────────────────────────
    values["platelets"] = extract_value(text, [
        r"platelet[\s:.\-–|]+(\d+\.?\d*)",
        r"plt[\s:.\-–|]+(\d+\.?\d*)",
        r"platelet\s*count[\s:.\-–|]+(\d+\.?\d*)",
        r"thrombocytes[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── RBC ──────────────────────────────────────────────────────────────
    values["rbc"] = extract_value(text, [
        r"rbc[\s:.\-–|]+(\d+\.?\d*)",
        r"red blood cell[\s:.\-–|]+(\d+\.?\d*)",
        r"erythrocytes[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # ── Remove None values for cleaner response ──────────────────────────
    return {k: v for k, v in values.items() if v is not None}


# ─── OCR Endpoint ───────────────────────────────────────────────────────

@router.post("/ocr/upload")
async def upload_lab_report(
    file: UploadFile = File(...),
    user_id: int = 1,
    db: Session = Depends(get_db)
):
    """
    Accept a lab report image (JPG/PNG) or PDF.
    Run Tesseract OCR, extract medical values, save to DB.
    """

    # ── Validate file type ───────────────────────────────────────────────
    allowed_types = ["image/jpeg", "image/png", "image/jpg", "application/pdf"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. Use JPG, PNG, or PDF."
        )

    raw_bytes = await file.read()

    # ── Convert PDF to image if needed ───────────────────────────────────
    if file.content_type == "application/pdf":
        try:
            from pdf2image import convert_from_bytes
            pages = convert_from_bytes(raw_bytes, dpi=300)
            if not pages:
                raise HTTPException(status_code=400, detail="Empty PDF")
            image = pages[0]  # Use first page only
        except ImportError:
            raise HTTPException(
                status_code=500,
                detail="pdf2image not installed. Run: pip install pdf2image"
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"PDF conversion failed: {str(e)}")
    else:
        image = Image.open(io.BytesIO(raw_bytes))

    # ── Run Tesseract OCR ────────────────────────────────────────────────
    try:
        # PSM 6 = assume uniform block of text — works well for lab reports
        custom_config = r'--oem 3 --psm 6'
        raw_text = pytesseract.image_to_string(image, config=custom_config)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR failed: {str(e)}")

    if not raw_text.strip():
        raise HTTPException(status_code=422, detail="OCR returned no text. Check image quality.")

    # ── Parse values from OCR text ───────────────────────────────────────
    extracted = parse_lab_values(raw_text)

    if not extracted:
        return {
            "status": "partial",
            "message": "OCR ran but no medical values were recognized. Check image quality.",
            "raw_text_preview": raw_text[:300],
            "extracted_values": {}
        }

    # ── Save to database ─────────────────────────────────────────────────
    try:
        report = LabReport(
            user_id=user_id,
            lab_name=file.filename or "uploaded_report",
            report_date="",
            glucose=extracted.get("glucose"),
            hemoglobin=extracted.get("hemoglobin"),
            cholesterol=extracted.get("cholesterol"),
            triglycerides=extracted.get("triglycerides"),
            creatinine=extracted.get("creatinine"),
        )
        db.add(report)
        db.commit()
        db.refresh(report)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database save failed: {str(e)}")

    return {
        "status": "success",
        "report_id": report.id,
        "extracted_values": extracted,
        "raw_text_preview": raw_text[:300]
    }