import re
import io
import os
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from fastapi.responses import JSONResponse

router = APIRouter()

# Set Tesseract path explicitly for Windows
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def preprocess_image(image: Image.Image) -> Image.Image:
    """Improve image quality before OCR."""
    # Convert to RGB
    if image.mode != 'RGB':
        image = image.convert('RGB')

    # Resize if too small — Tesseract works better on larger images
    w, h = image.size
    if w < 1000:
        scale = 1000 / w
        image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    # Convert to grayscale
    image = image.convert('L')

    # Increase contrast
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)

    # Sharpen
    image = image.filter(ImageFilter.SHARPEN)

    return image


def extract_value(text: str, patterns: list) -> float | None:
    """Try each pattern, return first match as float."""
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                raw = match.group(1).replace(',', '').strip()
                return float(raw)
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(text: str) -> dict:
    """Extract all medical values from OCR text."""
    results = {}

    # Glucose
    results['glucose'] = extract_value(text, [
        r'glucose[\s:.\-|=]+(\d+\.?\d*)',
        r'blood\s*sugar[\s:.\-|=]+(\d+\.?\d*)',
        r'fbs[\s:.\-|=]+(\d+\.?\d*)',
        r'rbs[\s:.\-|=]+(\d+\.?\d*)',
        r'glu[\s:.\-|=]+(\d+\.?\d*)',
        r'sugar[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Hemoglobin
    results['hemoglobin'] = extract_value(text, [
        r'h[ae]moglobin[\s:.\-|=]+(\d+\.?\d*)',
        r'\bhgb\b[\s:.\-|=]+(\d+\.?\d*)',
        r'\bhb\b[\s:.\-|=]+(\d+\.?\d*)',
        r'\bhemog[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Cholesterol
    results['cholesterol'] = extract_value(text, [
        r'total\s*cholesterol[\s:.\-|=]+(\d+\.?\d*)',
        r'cholesterol[\s:.\-|=]+(\d+\.?\d*)',
        r'\bchol\b[\s:.\-|=]+(\d+\.?\d*)',
        r'\btc\b[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Triglycerides
    results['triglycerides'] = extract_value(text, [
        r'triglycerides?[\s:.\-|=]+(\d+\.?\d*)',
        r'\btg\b[\s:.\-|=]+(\d+\.?\d*)',
        r'trigs?[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Creatinine
    results['creatinine'] = extract_value(text, [
        r'creatinine[\s:.\-|=]+(\d+\.?\d*)',
        r's\.?\s*creatinine[\s:.\-|=]+(\d+\.?\d*)',
        r'\bcreat\b[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # WBC
    results['wbc'] = extract_value(text, [
        r'wbc[\s:.\-|=]+(\d+\.?\d*)',
        r'white\s*blood\s*cell[\s:.\-|=]+(\d+\.?\d*)',
        r'leucocytes[\s:.\-|=]+(\d+\.?\d*)',
        r'tlc[\s:.\-|=]+(\d+\.?\d*)',
        r'total\s*wbc[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Platelets
    results['platelets'] = extract_value(text, [
        r'platelet[\s:.\-|=]+(\d+\.?\d*)',
        r'\bplt\b[\s:.\-|=]+(\d+\.?\d*)',
        r'platelet\s*count[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # RBC
    results['rbc'] = extract_value(text, [
        r'\brbc\b[\s:.\-|=]+(\d+\.?\d*)',
        r'red\s*blood\s*cell[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Uric acid
    results['uric_acid'] = extract_value(text, [
        r'uric\s*acid[\s:.\-|=]+(\d+\.?\d*)',
        r's\.?\s*uric[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Bilirubin
    results['bilirubin'] = extract_value(text, [
        r'total\s*bilirubin[\s:.\-|=]+(\d+\.?\d*)',
        r'bilirubin[\s:.\-|=]+(\d+\.?\d*)',
        r'\bsbil\b[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # SGPT / ALT
    results['sgpt'] = extract_value(text, [
        r'sgpt[\s:.\-|=]+(\d+\.?\d*)',
        r'\balt\b[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # SGOT / AST
    results['sgot'] = extract_value(text, [
        r'sgot[\s:.\-|=]+(\d+\.?\d*)',
        r'\bast\b[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # HbA1c
    results['hba1c'] = extract_value(text, [
        r'hba1c[\s:.\-|=]+(\d+\.?\d*)',
        r'glycat[\w\s]*[\s:.\-|=]+(\d+\.?\d*)',
    ])

    # Remove None values
    return {k: v for k, v in results.items() if v is not None}


@router.post('/ocr/upload')
async def upload_lab_report(file: UploadFile = File(...)):
    """
    Accept JPG, PNG, or PDF lab report.
    Run Tesseract OCR and extract medical values.
    """

    filename = file.filename or ''
    ext = filename.lower().rsplit('.', 1)[-1] if '.' in filename else ''
    allowed_ext = ['jpg', 'jpeg', 'png', 'pdf']

    if ext not in allowed_ext:
        raise HTTPException(
            status_code=400,
            detail=f'Unsupported file: {filename}. Use JPG, JPEG, PNG, or PDF.'
        )

    raw_bytes = await file.read()

    # Handle PDF — convert first page to image
    if ext == 'pdf':
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(stream=raw_bytes, filetype='pdf')
            page = doc[0]
            mat = fitz.Matrix(2.5, 2.5)  # zoom for better quality
            pix = page.get_pixmap(matrix=mat)
            img_bytes = pix.tobytes('png')
            image = Image.open(io.BytesIO(img_bytes))
        except ImportError:
            raise HTTPException(
                status_code=500,
                detail='PDF support needs PyMuPDF. Run: pip install PyMuPDF'
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f'PDF conversion failed: {str(e)}'
            )
    else:
        try:
            image = Image.open(io.BytesIO(raw_bytes))
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f'Cannot open image: {str(e)}'
            )

    # Preprocess image for better OCR
    try:
        processed = preprocess_image(image)
    except Exception as e:
        processed = image  # Use original if preprocessing fails

    # Run Tesseract OCR
    try:
        # Try multiple PSM modes and use the one with more text
        text_psm6 = pytesseract.image_to_string(processed, config='--oem 3 --psm 6')
        text_psm4 = pytesseract.image_to_string(processed, config='--oem 3 --psm 4')

        # Use whichever gave more text
        raw_text = text_psm6 if len(text_psm6) >= len(text_psm4) else text_psm4
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f'Tesseract OCR failed: {str(e)}. Make sure Tesseract is installed.'
        )

    if not raw_text.strip():
        return JSONResponse({
            'status': 'no_text',
            'message': 'OCR found no text. Use a clearer, well-lit image.',
            'extracted_values': {},
            'values_found': 0,
            'raw_text': ''
        })

    # Parse values
    extracted = parse_lab_values(raw_text)

    return JSONResponse({
        'status': 'success',
        'filename': filename,
        'extracted_values': extracted,
        'values_found': len(extracted),
        'raw_text': raw_text[:500]  # First 500 chars for debugging
    })