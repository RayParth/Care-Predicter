from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base, get_db
from routes_auth import router as auth_router
from routes_vitals import router as vitals_router
from routes_ocr import router as ocr_router
from routes_consult import router as consult_router
from sqlalchemy.orm import Session

# Create all database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Care Predicter API",
    description="AI-Driven Health Monitoring Backend",
    version="1.0.0"
)

# Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all routes
app.include_router(auth_router)
app.include_router(vitals_router)
app.include_router(ocr_router)
app.include_router(consult_router)

@app.get("/")
def root():
    return {
        "status": "Care Predicter API running",
        "version": "1.0.0",
        "endpoints": ["/auth", "/vitals", "/ocr", "/consult"]
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/labs/{user_id}")
def get_lab_reports(user_id: int, db: Session = Depends(get_db)):
    from models import LabReport
    reports = db.query(LabReport).filter(
        LabReport.user_id == user_id
    ).order_by(LabReport.uploaded_at.desc()).all()

    result = []
    for r in reports:
        result.append({
            "id": r.id,
            "lab_name": r.lab_name,
            "uploaded_at": r.uploaded_at.isoformat(),
            "glucose": r.glucose,
            "hemoglobin": r.hemoglobin,
            "cholesterol": r.cholesterol,
            "triglycerides": r.triglycerides,
            "creatinine": r.creatinine,
            "uric_acid": r.uric_acid,
            "wbc": r.wbc,
            "platelets": r.platelets,
            "rbc": r.rbc,
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