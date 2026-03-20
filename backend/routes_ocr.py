from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import pytesseract
from PIL import Image
import io
import re
import os

router = APIRouter(prefix="/ocr", tags=["ocr"])

# Point to Tesseract installation
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

def extract_lab_values(text: str) -> dict:
    results = {}
    text_lower = text.lower()

    patterns = {
        "glucose": [
            r"glucose[:\s]+(\d+\.?\d*)",
            r"blood\s*sugar[:\s]+(\d+\.?\d*)",
            r"fbs[:\s]+(\d+\.?\d*)",
            r"rbs[:\s]+(\d+\.?\d*)",
        ],
        "hemoglobin": [
            r"h[ae]moglobin[:\s]+(\d+\.?\d*)",
            r"\bhb\b[:\s]+(\d+\.?\d*)",
            r"\bhgb\b[:\s]+(\d+\.?\d*)",
        ],
        "cholesterol": [
            r"total\s*cholesterol[:\s]+(\d+\.?\d*)",
            r"cholesterol[:\s]+(\d+\.?\d*)",
        ],
        "triglycerides": [
            r"triglycerides?[:\s]+(\d+\.?\d*)",
            r"tg[:\s]+(\d+\.?\d*)",
        ],
        "creatinine": [
            r"creatinine[:\s]+(\d+\.?\d*)",
            r"s\.creatinine[:\s]+(\d+\.?\d*)",
        ],
        "uric_acid": [
            r"uric\s*acid[:\s]+(\d+\.?\d*)",
            r"s\.uric[:\s]+(\d+\.?\d*)",
        ],
        "wbc": [
            r"wbc[:\s]+(\d+\.?\d*)",
            r"white\s*blood\s*cell[s]?[:\s]+(\d+\.?\d*)",
            r"total\s*leucocyte[:\s]+(\d+\.?\d*)",
            r"tlc[:\s]+(\d+\.?\d*)",
        ],
        "platelets": [
            r"platelet[s]?[:\s]+(\d+\.?\d*)",
            r"plt[:\s]+(\d+\.?\d*)",
        ],
        "rbc": [
            r"rbc[:\s]+(\d+\.?\d*)",
            r"red\s*blood\s*cell[s]?[:\s]+(\d+\.?\d*)",
        ],
        "hba1c": [
            r"hba1c[:\s]+(\d+\.?\d*)",
            r"glycated\s*h[ae]moglobin[:\s]+(\d+\.?\d*)",
        ],
        "sgpt": [
            r"sgpt[:\s]+(\d+\.?\d*)",
            r"alt[:\s]+(\d+\.?\d*)",
        ],
        "sgot": [
            r"sgot[:\s]+(\d+\.?\d*)",
            r"ast[:\s]+(\d+\.?\d*)",
        ],
        "bilirubin": [
            r"total\s*bilirubin[:\s]+(\d+\.?\d*)",
            r"bilirubin[:\s]+(\d+\.?\d*)",
        ],
        "sodium": [
            r"sodium[:\s]+(\d+\.?\d*)",
            r"\bna\b[:\s]+(\d+\.?\d*)",
        ],
        "potassium": [
            r"potassium[:\s]+(\d+\.?\d*)",
            r"\bk\b[:\s]+(\d+\.?\d*)",
        ],
    }

    for key, pattern_list in patterns.items():
        for pattern in pattern_list:
            match = re.search(pattern, text_lower)
            if match:
                try:
                    value = float(match.group(1))
                    results[key] = value
                    break
                except ValueError:
                    continue

    return results

@router.post("/upload")
async def upload_lab_report(file: UploadFile = File(...)):
    allowed = ['image/jpeg', 'image/jpg', 'image/png',
               'application/pdf', 'image/tiff']

    content_type = file.content_type or ''

    # Allow by extension too
    filename = file.filename or ''
    ext = filename.lower().split('.')[-1] if '.' in filename else ''
    allowed_exts = ['jpg', 'jpeg', 'png', 'pdf', 'tiff']

    if content_type not in allowed and ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {content_type}. Allowed: JPG, PNG, PDF"
        )

    try:
        contents = await file.read()

        if ext == 'pdf' or content_type == 'application/pdf':
            # For PDF — convert first page to image
            try:
                import fitz  # PyMuPDF
                doc = fitz.open(stream=contents, filetype="pdf")
                page = doc[0]
                mat = fitz.Matrix(2, 2)  # 2x zoom for better OCR
                pix = page.get_pixmap(matrix=mat)
                img_data = pix.tobytes("png")
                image = Image.open(io.BytesIO(img_data))
            except ImportError:
                raise HTTPException(
                    status_code=500,
                    detail="PDF support requires PyMuPDF. Run: pip install PyMuPDF"
                )
        else:
            image = Image.open(io.BytesIO(contents))

        # Convert to RGB if needed
        if image.mode not in ('RGB', 'L'):
            image = image.convert('RGB')

        # OCR config — optimized for lab reports
        custom_config = r'--oem 3 --psm 6'
        extracted_text = pytesseract.image_to_string(
            image, config=custom_config
        )

        lab_values = extract_lab_values(extracted_text)

        return JSONResponse({
            "status": "success",
            "filename": filename,
            "extracted_text": extracted_text[:1000],
            "lab_values": lab_values,
            "values_found": len(lab_values)
        })

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"OCR extraction failed: {str(e)}"
        )