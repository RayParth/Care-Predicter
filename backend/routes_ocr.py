import re
import io
import pytesseract
from PIL import Image
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import LabReport

router = APIRouter()

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


def extract_value(text: str, patterns: list) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(",", "").strip())
            except (ValueError, AttributeError):
                continue
    return None


def parse_lab_values(raw_text: str) -> dict:
    text = raw_text

    values = {}

    values["glucose"] = extract_value(text, [
        r"glucose[\s:.\-–|]+(\d+\.?\d*)",
        r"blood[\s]*sugar[\s:.\-–|]+(\d+\.?\d*)",
        r"fbs[\s:.\-–|]+(\d+\.?\d*)",
        r"rbs[\s:.\-–|]+(\d+\.?\d*)",
        r"glu[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["hemoglobin"] = extract_value(text, [
        r"h[ae]moglobin[\s:.\-–|]+(\d+\.?\d*)",
        r"\bhgb\b[\s:.\-–|]+(\d+\.?\d*)",
        r"\bhb\b[\s:.\-–|]+(\d+\.?\d*)",
        r"haemoglobin[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["cholesterol"] = extract_value(text, [
        r"total[\s]*cholesterol[\s:.\-–|]+(\d+\.?\d*)",
        r"cholesterol[\s:.\-–|]+(\d+\.?\d*)",
        r"\bchol\b[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["triglycerides"] = extract_value(text, [
        r"triglycerides?[\s:.\-–|]+(\d+\.?\d*)",
        r"\btg\b[\s:.\-–|]+(\d+\.?\d*)",
        r"trigs?[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["creatinine"] = extract_value(text, [
        r"creatinine[\s:.\-–|]+(\d+\.?\d*)",
        r"s\.?\s*creatinine[\s:.\-–|]+(\d+\.?\d*)",
        r"creat[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["uric_acid"] = extract_value(text, [
        r"uric[\s]*acid[\s:.\-–|]+(\d+\.?\d*)",
        r"s\.uric[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["wbc"] = extract_value(text, [
        r"wbc[\s:.\-–|]+(\d+\.?\d*)",
        r"white[\s]*blood[\s]*cell[\s:.\-–|]+(\d+\.?\d*)",
        r"leucocytes[\s:.\-–|]+(\d+\.?\d*)",
        r"\btlc\b[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["platelets"] = extract_value(text, [
        r"platelet[\s]*count[\s:.\-–|]+(\d+\.?\d*)",
        r"platelets?[\s:.\-–|]+(\d+\.?\d*)",
        r"\bplt\b[\s:.\-–|]+(\d+\.?\d*)",
        r"thrombocytes[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["rbc"] = extract_value(text, [
        r"rbc[\s:.\-–|]+(\d+\.?\d*)",
        r"red[\s]*blood[\s]*cell[\s:.\-–|]+(\d+\.?\d*)",
        r"erythrocytes[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["hba1c"] = extract_value(text, [
        r"hba1c[\s:.\-–|]+(\d+\.?\d*)",
        r"hb[\s]*a1c[\s:.\-–|]+(\d+\.?\d*)",
        r"glycated[\s]*h[ae]moglobin[\s:.\-–|]+(\d+\.?\d*)",
        r"glycosylated[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["sgpt"] = extract_value(text, [
        r"sgpt[\s:.\-–|]+(\d+\.?\d*)",
        r"\balt\b[\s:.\-–|]+(\d+\.?\d*)",
        r"alanine[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["sgot"] = extract_value(text, [
        r"sgot[\s:.\-–|]+(\d+\.?\d*)",
        r"\bast\b[\s:.\-–|]+(\d+\.?\d*)",
        r"aspartate[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["bilirubin"] = extract_value(text, [
        r"total[\s]*bilirubin[\s:.\-–|]+(\d+\.?\d*)",
        r"bilirubin[\s:.\-–|]+(\d+\.?\d*)",
        r"\bbili\b[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["sodium"] = extract_value(text, [
        r"sodium[\s:.\-–|]+(\d+\.?\d*)",
        r"\bna\+?[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["potassium"] = extract_value(text, [
        r"potassium[\s:.\-–|]+(\d+\.?\d*)",
        r"\bk\+?[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["calcium"] = extract_value(text, [
        r"calcium[\s:.\-–|]+(\d+\.?\d*)",
        r"\bca\b[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["vitamin_d"] = extract_value(text, [
        r"vitamin[\s]*d[\s:.\-–|]+(\d+\.?\d*)",
        r"25[\s]*oh[\s]*d[\s:.\-–|]+(\d+\.?\d*)",
        r"25-hydroxyvitamin[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["vitamin_b12"] = extract_value(text, [
        r"vitamin[\s]*b[\s]*12[\s:.\-–|]+(\d+\.?\d*)",
        r"b12[\s:.\-–|]+(\d+\.?\d*)",
        r"cobalamin[\s:.\-–|]+(\d+\.?\d*)",
    ])

    values["tsh"] = extract_value(text, [
        r"tsh[\s:.\-–|]+(\d+\.?\d*)",
        r"thyroid[\s]*stimulating[\s:.\-–|]+(\d+\.?\d*)",
    ])

    # Remove None values
    return {k: v for k, v in values.items() if v is not None}


def image_to_text(image: Image.Image) -> str:
    # Try multiple PSM modes for best results
    configs = [
        r'--oem 3 --psm 6',   # Uniform block of text
        r'--oem 3 --psm 4',   # Single column
        r'--oem 3 --psm 11',  # Sparse text
    ]
    best_text = ''
    best_count = 0

    for cfg in configs:
        try:
            text = pytesseract.image_to_string(image, config=cfg)
            # Pick config that extracts most content
            if len(text.strip()) > best_count:
                best_text = text
                best_count = len(text.strip())
        except Exception:
            continue

    return best_text


@router.post("/ocr/upload")
async def upload_lab_report(
    file: UploadFile = File(...),
    user_id: int = 1,
    db: Session = Depends(get_db)
):
    filename = file.filename or ''
    ext = filename.lower().rsplit('.', 1)[-1] if '.' in filename else ''
    content_type = file.content_type or ''

    allowed_exts = ['jpg', 'jpeg', 'png', 'pdf', 'tiff', 'bmp']
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file: .{ext}. Allowed: JPG, JPEG, PNG, PDF"
        )

    raw_bytes = await file.read()
    image = None

    # Handle PDF using PyMuPDF
    if ext == 'pdf' or 'pdf' in content_type:
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(stream=raw_bytes, filetype="pdf")
            if len(doc) == 0:
                raise HTTPException(status_code=400, detail="Empty PDF file")

            # Render first page at high resolution
            page = doc[0]
            mat = fitz.Matrix(3.0, 3.0)  # 3x zoom = ~216 DPI
            pix = page.get_pixmap(matrix=mat)
            img_bytes = pix.tobytes("png")
            image = Image.open(io.BytesIO(img_bytes)).convert("RGB")

        except ImportError:
            raise HTTPException(
                status_code=500,
                detail="PyMuPDF not installed. Run: pip install PyMuPDF"
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"PDF conversion failed: {str(e)}"
            )
    else:
        try:
            image = Image.open(io.BytesIO(raw_bytes))
            # Convert to RGB for consistent OCR
            if image.mode not in ('RGB', 'L'):
                image = image.convert('RGB')
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot open image: {str(e)}"
            )

    if image is None:
        raise HTTPException(status_code=500, detail="Failed to process file")

    # Enhance image for better OCR
    try:
        from PIL import ImageEnhance, ImageFilter
        # Sharpen and increase contrast
        image = image.filter(ImageFilter.SHARPEN)
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(1.5)
    except Exception:
        pass  # Enhancement is optional

    # Run OCR
    try:
        raw_text = image_to_text(image)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"OCR failed: {str(e)}"
        )

    if not raw_text.strip():
        raise HTTPException(
            status_code=422,
            detail="OCR returned no text. Try a clearer image or better lighting."
        )

    # Parse values
    extracted = parse_lab_values(raw_text)

    # Save to database
    try:
        report = LabReport(
            user_id=user_id,
            lab_name=filename or "uploaded_report",
            report_date="",
            glucose=extracted.get("glucose"),
            hemoglobin=extracted.get("hemoglobin"),
            cholesterol=extracted.get("cholesterol"),
            triglycerides=extracted.get("triglycerides"),
            creatinine=extracted.get("creatinine"),
            uric_acid=extracted.get("uric_acid"),
            wbc=extracted.get("wbc"),
            platelets=extracted.get("platelets"),
            raw_text=raw_text[:2000],
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        report_id = report.id
    except Exception as e:
        db.rollback()
        report_id = None
        print(f"DB save error: {e}")

    if not extracted:
        return {
            "status": "partial",
            "message": "OCR ran but no standard medical values found. Try a clearer image.",
            "extracted_values": {},
            "lab_values": {},
            "raw_text_preview": raw_text[:500],
        }

    return {
        "status": "success",
        "report_id": report_id,
        "extracted_values": extracted,
        "lab_values": extracted,        # Flutter reads this key
        "values_found": len(extracted),
        "raw_text_preview": raw_text[:500],
    }