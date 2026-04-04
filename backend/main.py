from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from database import engine, Base, get_db
from models import LabReport
from config import settings

# Import from the new routes folder
from routes.auth import router as auth_router
from routes.vitals import router as vitals_router
from routes.ocr import router as ocr_router
from routes.consult import router as consult_router

# Create all database tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    docs_url=None if settings.ENV == "production" else "/docs",
    redoc_url=None if settings.ENV == "production" else "/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(vitals_router)
app.include_router(ocr_router)
app.include_router(consult_router)


@app.get("/")
def root():
    return {
        "status": f"{settings.APP_NAME} running",
        "version": settings.APP_VERSION,
        "endpoints": ["/auth", "/vitals", "/ocr", "/consult"]
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


# Lab report endpoints (kept in main.py as they don't have their own router yet)
@app.get("/labs/{user_id}")
def get_lab_reports(user_id: int, db: Session = Depends(get_db)):
    reports = db.query(LabReport).filter(
        LabReport.user_id == user_id
    ).order_by(LabReport.uploaded_at.desc()).all()

    result = []
    for r in reports:
        result.append({
            "id": r.id,
            "lab_name": r.lab_name,
            "uploaded_at": r.uploaded_at.isoformat(),
            "hemoglobin": r.hemoglobin,
            "rbc": r.rbc,
            "wbc": r.wbc,
            "platelets": r.platelets,
            "glucose": r.glucose,
            "cholesterol": r.cholesterol,
            "triglycerides": r.triglycerides,
            "creatinine": r.creatinine,
            "uric_acid": r.uric_acid,
            "bilirubin": r.bilirubin,
            "sgpt": r.sgpt,
            "sgot": r.sgot,
            "hba1c": r.hba1c,
            "tsh": r.tsh,
            "vitamin_d": r.vitamin_d,
            "vitamin_b12": r.vitamin_b12,
            "sodium": r.sodium,
            "potassium": r.potassium,
            "calcium": r.calcium,
            "ldl": r.ldl,
            "hdl": r.hdl,
        })
    return result


@app.get("/labs/{user_id}/latest")
def get_latest_lab(user_id: int, db: Session = Depends(get_db)):
    report = db.query(LabReport).filter(
        LabReport.user_id == user_id
    ).order_by(LabReport.uploaded_at.desc()).first()

    if not report:
        return {"status": "no_data"}

    return {
        "status": "ok",
        "id": report.id,
        "lab_name": report.lab_name,
        "uploaded_at": report.uploaded_at.isoformat(),
        "hemoglobin": report.hemoglobin,
        "rbc": report.rbc,
        "wbc": report.wbc,
        "platelets": report.platelets,
        "glucose": report.glucose,
        "cholesterol": report.cholesterol,
        "triglycerides": report.triglycerides,
        "creatinine": report.creatinine,
        "uric_acid": report.uric_acid,
        "bilirubin": report.bilirubin,
        "sgpt": report.sgpt,
        "sgot": report.sgot,
        "hba1c": report.hba1c,
        "tsh": report.tsh,
        "vitamin_d": report.vitamin_d,
        "vitamin_b12": report.vitamin_b12,
        "sodium": report.sodium,
        "potassium": report.potassium,
        "ldl": report.ldl,
        "hdl": report.hdl,
    }