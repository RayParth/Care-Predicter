import re
import io
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from database import get_db
from models import LabReport, User

router = APIRouter()

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def preprocess_image(image: Image.Image) -> Image.Image:
    if image.mode != 'RGB':
        image = image.convert('RGB')
    w, h = image.size
    if w < 1400:
        scale = 1400 / w
        image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    image = image.convert('L')
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)
    image = image.filter(ImageFilter.SHARPEN)
    return image


def extract_value(text: str, patterns: list) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            try:
                raw = match.group(1).replace(',', '').strip()
                val = float(raw)
                if 0 < val < 1000000:
                    return val
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(text: str) -> dict:
    results = {}

    # ── Hemoglobin ─────────────────────────────────────────────────────
    # Matches: "Hb   13.7 gm %" or "HGB   13.7" or "Hemoglobin 13.7"
    results['hemoglobin'] = extract_value(text, [
        r'\bHb\b[\s:.\-|=*]+(\d+\.?\d*)\s*gm',
        r'\bHGB\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Hh]aemoglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Hh]emoglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bHgb\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bHb\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── RBC ─────────────────────────────────────────────────────────────
    # Matches: "RBC   4.68 mil/cmm"
    results['rbc'] = extract_value(text, [
        r'\bRBC\b[\s:.\-|=*]+(\d+\.?\d*)\s*mil',
        r'\bRBC\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Rr]ed\s*[Bb]lood\s*[Cc]ell[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Ee]rythrocyte[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── WBC ─────────────────────────────────────────────────────────────
    # Matches: "Total W.B.C.   3120 per cu mm" or "WBC   3.12"
    results['wbc'] = extract_value(text, [
        r'[Tt]otal\s*W\.?B\.?C\.?[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bWBC\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Ll]eucocyte[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bTLC\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Ww]hite\s*[Bb]lood[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Platelets ───────────────────────────────────────────────────────
    # Matches: "Platelets (Fluorescent)   138000 per cumm" or "PLT &F   138"
    results['platelets'] = extract_value(text, [
        r'[Pp]latelets?\s*\([Ff]luorescent\)[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Pp]latelets?\s*\(IPF\)[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Pp]latelet\s*[Cc]ount[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bPLT\s*&?F?\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bPLT\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Pp]latelet[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── MCV ─────────────────────────────────────────────────────────────
    results['mcv'] = extract_value(text, [
        r'\bM\.?C\.?V\.?\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bMCV\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── MCH ─────────────────────────────────────────────────────────────
    results['mch'] = extract_value(text, [
        r'\bM\.?C\.?H\.?\b[\s:.\-|=*]+(\d+\.?\d*)\s*[Pp]g',
        r'\bMCH\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Glucose ─────────────────────────────────────────────────────────
    results['glucose'] = extract_value(text, [
        r'[Gg]lucose\s*\([Ff]asting\)[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Gg]lucose\s*\([Rr]andom\)[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Gg]lucose[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bFBS\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bRBS\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Bb]lood\s*[Ss]ugar[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Cholesterol ─────────────────────────────────────────────────────
    results['cholesterol'] = extract_value(text, [
        r'[Tt]otal\s*[Cc]holesterol[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Cc]holesterol,\s*[Tt]otal[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Cc]holesterol[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Triglycerides ───────────────────────────────────────────────────
    results['triglycerides'] = extract_value(text, [
        r'[Tt]riglycerides?[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bTG\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Creatinine ──────────────────────────────────────────────────────
    results['creatinine'] = extract_value(text, [
        r'[Ss]erum\s*[Cc]reatinine[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Cc]reatinine[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bCREAT\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Uric Acid ───────────────────────────────────────────────────────
    results['uric_acid'] = extract_value(text, [
        r'[Uu]ric\s*[Aa]cid[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Ss]erum\s*[Uu]ric[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Bilirubin ───────────────────────────────────────────────────────
    results['bilirubin'] = extract_value(text, [
        r'[Tt]otal\s*[Bb]ilirubin[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Bb]ilirubin[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── SGPT / ALT ──────────────────────────────────────────────────────
    results['sgpt'] = extract_value(text, [
        r'\bSGPT\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bALT\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── SGOT / AST ──────────────────────────────────────────────────────
    results['sgot'] = extract_value(text, [
        r'\bSGOT\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bAST\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── HbA1c ───────────────────────────────────────────────────────────
    results['hba1c'] = extract_value(text, [
        r'[Hh][Bb][Aa]1[Cc][\s:.\-|=*]+(\d+\.?\d*)',
        r'[Gg]lycated\s*[Hh][ae]moglobin[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Aa]1[Cc][\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── TSH ─────────────────────────────────────────────────────────────
    results['tsh'] = extract_value(text, [
        r'\bTSH\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Tt]hyroid\s*[Ss]timulating[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Vitamin D ───────────────────────────────────────────────────────
    results['vitamin_d'] = extract_value(text, [
        r'[Vv]itamin\s*[Dd][\s:.\-|=*]+(\d+\.?\d*)',
        r'25[\s\-]*[Oo][Hh][\s\-]*[Dd][\s:.\-|=*]+(\d+\.?\d*)',
        r'[Vv]it\.?\s*[Dd][\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Vitamin B12 ─────────────────────────────────────────────────────
    results['vitamin_b12'] = extract_value(text, [
        r'[Vv]itamin\s*[Bb][\s\-]*12[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bB[\s\-]*12\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Sodium ──────────────────────────────────────────────────────────
    results['sodium'] = extract_value(text, [
        r'[Ss]odium[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bNa\+?[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── Potassium ───────────────────────────────────────────────────────
    results['potassium'] = extract_value(text, [
        r'[Pp]otassium[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bK\+?[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── LDL ─────────────────────────────────────────────────────────────
    results['ldl'] = extract_value(text, [
        r'\bLDL\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Ll]ow\s*[Dd]ensity[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── HDL ─────────────────────────────────────────────────────────────
    results['hdl'] = extract_value(text, [
        r'\bHDL\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'[Hh]igh\s*[Dd]ensity[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # ── PCV / HCT ───────────────────────────────────────────────────────
    results['pcv'] = extract_value(text, [
        r'\bP\.?C\.?V\.?\b[\s:.\-|=*]+(\d+\.?\d*)',
        r'\bHCT\b[\s:.\-|=*]+(\d+\.?\d*)',
    ])

    # Remove None values
    return {k: v for k, v in results.items() if v is not None}


def ocr_image(image: Image.Image) -> str:
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
async def upload_lab_report(
    file: UploadFile = File(...),
    user_id: int = 1,
    db: Session = Depends(get_db)
):
    filename = file.filename or ''
    ext = filename.lower().rsplit('.', 1)[-1] if '.' in filename else ''

    if ext not in ['jpg', 'jpeg', 'png', 'pdf']:
        raise HTTPException(status_code=400,
            detail=f'Unsupported: {filename}. Use JPG, JPEG, PNG or PDF.')

    raw_bytes = await file.read()
    all_text = ''

    if ext == 'pdf':
        try:
            import fitz
            doc = fitz.open(stream=raw_bytes, filetype='pdf')
            print(f'PDF pages: {len(doc)}')
            for i in range(len(doc)):
                page = doc[i]
                mat = fitz.Matrix(3.0, 3.0)
                pix = page.get_pixmap(matrix=mat)
                img = Image.open(io.BytesIO(pix.tobytes('png')))
                page_text = ocr_image(img)
                all_text += f'\n--- PAGE {i+1} ---\n{page_text}'
                print(f'Page {i+1}: {len(page_text)} chars')
        except ImportError:
            raise HTTPException(status_code=500,
                detail='Run: pip install PyMuPDF')
        except Exception as e:
            raise HTTPException(status_code=500,
                detail=f'PDF error: {str(e)}')
    else:
        try:
            image = Image.open(io.BytesIO(raw_bytes))
            all_text = ocr_image(image)
        except Exception as e:
            raise HTTPException(status_code=400,
                detail=f'Image error: {str(e)}')

    print(f'Total OCR text: {len(all_text)} chars')
    print('--- OCR TEXT PREVIEW ---')
    print(all_text[:2000])
    print('--- END PREVIEW ---')

    extracted = parse_lab_values(all_text)
    print(f'Extracted: {extracted}')

    if not all_text.strip():
        return JSONResponse({
            'status': 'no_text',
            'extracted_values': {},
            'values_found': 0,
            'raw_text': ''
        })

    # Save to DB linked to user_id
    try:
        report = LabReport(
            user_id=user_id,
            lab_name=filename,
            report_date='',
            hemoglobin=extracted.get('hemoglobin'),
            rbc=extracted.get('rbc'),
            wbc=extracted.get('wbc'),
            platelets=extracted.get('platelets'),
            glucose=extracted.get('glucose'),
            cholesterol=extracted.get('cholesterol'),
            triglycerides=extracted.get('triglycerides'),
            creatinine=extracted.get('creatinine'),
            uric_acid=extracted.get('uric_acid'),
            bilirubin=extracted.get('bilirubin'),
            sgpt=extracted.get('sgpt'),
            sgot=extracted.get('sgot'),
            hba1c=extracted.get('hba1c'),
            tsh=extracted.get('tsh'),
            vitamin_d=extracted.get('vitamin_d'),
            vitamin_b12=extracted.get('vitamin_b12'),
            sodium=extracted.get('sodium'),
            potassium=extracted.get('potassium'),
            ldl=extracted.get('ldl'),
            hdl=extracted.get('hdl'),
            raw_text=all_text[:3000],
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        report_id = report.id
        print(f'Saved to DB: report_id={report_id}')
    except Exception as e:
        db.rollback()
        report_id = None
        print(f'DB save error: {e}')

    return JSONResponse({
        'status': 'success' if extracted else 'no_values',
        'filename': filename,
        'extracted_values': extracted,
        'values_found': len(extracted),
        'raw_text': all_text[:1000]
    })