import re
import io
import os
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse

router = APIRouter()

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def preprocess_image(image: Image.Image) -> Image.Image:
    if image.mode != 'RGB':
        image = image.convert('RGB')
    w, h = image.size
    if w < 1200:
        scale = 1200 / w
        image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    image = image.convert('L')
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)
    image = image.filter(ImageFilter.SHARPEN)
    return image


def extract_value(text: str, patterns: list) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                raw = match.group(1).replace(',', '').strip()
                val = float(raw)
                # Sanity check — ignore obviously wrong values
                if val > 0 and val < 100000:
                    return val
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(text: str) -> dict:
    results = {}

    results['glucose'] = extract_value(text, [
        r'glucose[\s:.\-|=*]+(\d+\.?\d*)',
        r'blood\s*sugar[\s:.\-|=*]+(\d+\.?\d*)',
        r'fbs[\s:.\-|=*]+(\d+\.?\d*)',
        r'rbs[\s:.\-|=*]+(\d+\.?\d*)',
        r'glu[\s:.\-|=*]+(\d+\.?\d*)',
        r'sugar[\s:.\-|=*]+(\d+\.?\d*)',
        r'glucose\s*\(fasting\)[\s:.\-|=*]+(\d+\.?\d*)',
        r'glucose\s*\(random\)[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['hemoglobin'] = extract_value(text, [
        r'h[ae]moglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bhgb\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bhb\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'haemoglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'hemoglobin[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['cholesterol'] = extract_value(text, [
        r'total\s*cholesterol[\s:.\-|=*]+(\d+\.?\d*)',
        r'cholesterol,\s*total[\s:.\-|=*]+(\d+\.?\d*)',
        r'cholesterol[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bchol\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['triglycerides'] = extract_value(text, [
        r'triglycerides?[\s:.\-|=*]+(\d+\.?\d*)',
        r'\btg\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'trigs?[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*triglycerides?[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['creatinine'] = extract_value(text, [
        r'creatinine[\s:.\-|=*]+(\d+\.?\d*)',
        r's\.?\s*creatinine[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*creatinine[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bcreat\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['uric_acid'] = extract_value(text, [
        r'uric\s*acid[\s:.\-|=*]+(\d+\.?\d*)',
        r's\.?\s*uric[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*uric\s*acid[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['wbc'] = extract_value(text, [
        r'wbc[\s:.\-|=*]+(\d+\.?\d*)',
        r'white\s*blood\s*cell[\s:.\-|=*]+(\d+\.?\d*)',
        r'leucocytes[\s:.\-|=*]+(\d+\.?\d*)',
        r'tlc[\s:.\-|=*]+(\d+\.?\d*)',
        r'total\s*wbc[\s:.\-|=*]+(\d+\.?\d*)',
        r'total\s*leucocyte[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['platelets'] = extract_value(text, [
        r'platelet[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bplt\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'platelet\s*count[\s:.\-|=*]+(\d+\.?\d*)',
        r'thrombocyte[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['rbc'] = extract_value(text, [
        r'\brbc\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'red\s*blood\s*cell[\s:.\-|=*]+(\d+\.?\d*)',
        r'erythrocyte[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['bilirubin'] = extract_value(text, [
        r'total\s*bilirubin[\s:.\-|=*]+(\d+\.?\d*)',
        r'bilirubin[\s:.\-|=*]+(\d+\.?\d*)',
        r't\.?\s*bili[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['sgpt'] = extract_value(text, [
        r'sgpt[\s:.\-|=*]+(\d+\.?\d*)',
        r'\balt\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'alanine\s*aminotransferase[\s:.\-|=*]+(\d+\.?\d*)',
        r'alanine\s*transaminase[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['sgot'] = extract_value(text, [
        r'sgot[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bast\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'aspartate\s*aminotransferase[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['hba1c'] = extract_value(text, [
        r'hba1c[\s:.\-|=*]+(\d+\.?\d*)',
        r'hb\s*a1c[\s:.\-|=*]+(\d+\.?\d*)',
        r'glycated\s*h[ae]moglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'glycosylated\s*h[ae]moglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'a1c[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['tsh'] = extract_value(text, [
        r'tsh[\s:.\-|=*]+(\d+\.?\d*)',
        r'thyroid\s*stimulating[\s:.\-|=*]+(\d+\.?\d*)',
        r't\.?\s*s\.?\s*h\.?[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['vitamin_d'] = extract_value(text, [
        r'vitamin\s*d[\s:.\-|=*]+(\d+\.?\d*)',
        r'25[\s\-]*oh[\s\-]*d[\s:.\-|=*]+(\d+\.?\d*)',
        r'25\s*hydroxy[\s:.\-|=*]+(\d+\.?\d*)',
        r'vit\.?\s*d[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['vitamin_b12'] = extract_value(text, [
        r'vitamin\s*b[\s\-]*12[\s:.\-|=*]+(\d+\.?\d*)',
        r'b[\s\-]*12[\s:.\-|=*]+(\d+\.?\d*)',
        r'cobalamin[\s:.\-|=*]+(\d+\.?\d*)',
        r'cyanocobalamin[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['sodium'] = extract_value(text, [
        r'sodium[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bna\+?[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*sodium[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['potassium'] = extract_value(text, [
        r'potassium[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bk\+?[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*potassium[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['calcium'] = extract_value(text, [
        r'calcium[\s:.\-|=*]+(\d+\.?\d*)',
        r'serum\s*calcium[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bca\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['ldl'] = extract_value(text, [
        r'ldl[\s:.\-|=*]+(\d+\.?\d*)',
        r'ldl[\s\-]*cholesterol[\s:.\-|=*]+(\d+\.?\d*)',
        r'low\s*density[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    results['hdl'] = extract_value(text, [
        r'hdl[\s:.\-|=*]+(\d+\.?\d*)',
        r'hdl[\s\-]*cholesterol[\s:.\-|=*]+(\d+\.?\d*)',
        r'high\s*density[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    return {k: v for k, v in results.items() if v is not None}


def ocr_image(image: Image.Image) -> str:
    """Run OCR with multiple configs, return best result."""
    processed = preprocess_image(image)
    best = ''
    for cfg in [r'--oem 3 --psm 6', r'--oem 3 --psm 4', r'--oem 3 --psm 3']:
        try:
            text = pytesseract.image_to_string(processed, config=cfg)
            if len(text.strip()) > len(best.strip()):
                best = text
        except Exception:
            continue
    return best


@router.post('/ocr/upload')
async def upload_lab_report(file: UploadFile = File(...)):
    filename = file.filename or ''
    ext = filename.lower().rsplit('.', 1)[-1] if '.' in filename else ''

    if ext not in ['jpg', 'jpeg', 'png', 'pdf']:
        raise HTTPException(
            status_code=400,
            detail=f'Unsupported file: {filename}. Use JPG, JPEG, PNG, or PDF.'
        )

    raw_bytes = await file.read()
    all_text = ''

    if ext == 'pdf':
        # ── Scan ALL pages of the PDF ────────────────────────────────
        try:
            import fitz
            doc = fitz.open(stream=raw_bytes, filetype='pdf')

            if len(doc) == 0:
                raise HTTPException(status_code=400, detail='Empty PDF file')

            print(f'PDF has {len(doc)} pages — scanning all pages')

            for page_num in range(len(doc)):
                page = doc[page_num]
                # High resolution render
                mat = fitz.Matrix(3.0, 3.0)
                pix = page.get_pixmap(matrix=mat)
                img_bytes = pix.tobytes('png')
                image = Image.open(io.BytesIO(img_bytes))
                page_text = ocr_image(image)
                all_text += f'\n--- PAGE {page_num + 1} ---\n{page_text}'
                print(f'Page {page_num + 1}: extracted {len(page_text)} chars')

        except ImportError:
            raise HTTPException(
                status_code=500,
                detail='PyMuPDF not installed. Run: pip install PyMuPDF'
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f'PDF processing failed: {str(e)}'
            )
    else:
        try:
            image = Image.open(io.BytesIO(raw_bytes))
            all_text = ocr_image(image)
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f'Cannot open image: {str(e)}'
            )

    if not all_text.strip():
        return JSONResponse({
            'status': 'no_text',
            'message': 'OCR found no text. Use a clearer, well-lit image.',
            'extracted_values': {},
            'values_found': 0,
            'raw_text': ''
        })

    print(f'Total OCR text length: {len(all_text)} chars')
    print(f'First 500 chars: {all_text[:500]}')

    extracted = parse_lab_values(all_text)

    print(f'Extracted values: {extracted}')

    if not extracted:
        return JSONResponse({
            'status': 'no_values',
            'message': 'OCR ran but no medical values found.',
            'extracted_values': {},
            'values_found': 0,
            'raw_text': all_text[:1000]
        })

    return JSONResponse({
        'status': 'success',
        'filename': filename,
        'extracted_values': extracted,
        'values_found': len(extracted),
        'raw_text': all_text[:1000]
    })