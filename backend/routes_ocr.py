from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import pytesseract
from PIL import Image
import io
import re

router = APIRouter(prefix="/ocr", tags=["ocr"])

def extract_lab_values(text: str) -> dict:
    results = {}
    patterns = {
        "glucose": r"glucose[:\s]+(\d+\.?\d*)",
        "hemoglobin": r"h[ae]moglobin[:\s]+(\d+\.?\d*)",
        "cholesterol": r"cholesterol[:\s]+(\d+\.?\d*)",
        "triglycerides": r"triglycerides?[:\s]+(\d+\.?\d*)",
        "creatinine": r"creatinine[:\s]+(\d+\.?\d*)",
        "uric_acid": r"uric\s*acid[:\s]+(\d+\.?\d*)",
        "wbc": r"wbc[:\s]+(\d+\.?\d*)",
        "platelets": r"platelets?[:\s]+(\d+\.?\d*)",
        "hemoglobin_alt": r"hb[:\s]+(\d+\.?\d*)",
    }
    text_lower = text.lower()
    for key, pattern in patterns.items():
        match = re.search(pattern, text_lower)
        if match:
            clean_key = key.replace("_alt", "")
            results[clean_key] = float(match.group(1))
    return results

@router.post("/upload")
async def upload_lab_report(file: UploadFile = File(...)):
    if not file.content_type.startswith(("image/", "application/pdf")):
        raise HTTPException(
            status_code=400,
            detail="Only image or PDF files are supported"
        )
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        extracted_text = pytesseract.image_to_string(image)
        lab_values = extract_lab_values(extracted_text)
        return JSONResponse({
            "status": "success",
            "extracted_text": extracted_text[:500],
            "lab_values": lab_values,
            "values_found": len(lab_values)
        })
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"OCR extraction failed: {str(e)}"
        )