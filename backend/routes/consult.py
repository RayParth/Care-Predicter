from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Consultation, User, Vital, LabReport
from schemas import ConsultCreate
from pydantic import BaseModel

router = APIRouter(prefix="/consult", tags=["consult"])


# Helper: build full patient data for a consultation

def _build_consultation_detail(c: Consultation, db: Session) -> dict:
    patient = db.query(User).filter(User.id == c.patient_id).first()

    vital = db.query(Vital).filter(
        Vital.user_id == c.patient_id
    ).order_by(Vital.recorded_at.desc()).first()

    lab = db.query(LabReport).filter(
        LabReport.user_id == c.patient_id
    ).order_by(LabReport.uploaded_at.desc()).first()

    return {
        "id":          c.id,
        "status":      c.status,
        "ai_summary":  c.ai_summary,
        "doctor_name": c.doctor_name,
        "created_at":  c.created_at.isoformat() if c.created_at else None,

        "patient": {
            "id":          patient.id          if patient else None,
            "name":        patient.name        if patient else "Unknown",
            "email":       patient.email       if patient else "",
            "age":         patient.age         if patient else None,
            "gender":      patient.gender      if patient else None,
            "blood_group": patient.blood_group if patient else None,
            "weight":      patient.weight      if patient else None,
            "height":      patient.height      if patient else None,
        } if patient else None,

        "vitals": {
            "heart_rate":  vital.heart_rate  if vital else None,
            "spo2":        vital.spo2        if vital else None,
            "steps":       vital.steps       if vital else None,
            "calories":    vital.calories    if vital else None,
            "sleep_hours": vital.sleep_hours if vital else None,
            "temperature": vital.temperature if vital else None,
            "recorded_at": vital.recorded_at.isoformat() if vital else None,
        } if vital else None,

        "labs": {
            "hemoglobin":    lab.hemoglobin    if lab else None,
            "rbc":           lab.rbc           if lab else None,
            "wbc":           lab.wbc           if lab else None,
            "platelets":     lab.platelets     if lab else None,
            "glucose":       lab.glucose       if lab else None,
            "cholesterol":   lab.cholesterol   if lab else None,
            "triglycerides": lab.triglycerides if lab else None,
            "creatinine":    lab.creatinine    if lab else None,
            "uric_acid":     lab.uric_acid     if lab else None,
            "sgpt":          lab.sgpt          if lab else None,
            "sgot":          lab.sgot          if lab else None,
            "hba1c":         lab.hba1c         if lab else None,
            "tsh":           lab.tsh           if lab else None,
            "vitamin_d":     lab.vitamin_d     if lab else None,
            "vitamin_b12":   lab.vitamin_b12   if lab else None,
            "ldl":           lab.ldl           if lab else None,
            "hdl":           lab.hdl           if lab else None,
            "lab_name":      lab.lab_name      if lab else None,
            "uploaded_at":   lab.uploaded_at.isoformat() if lab else None,
        } if lab else None,
    }


# POST /consult/ — Patient creates a consultation request

@router.post("/")
def create_consultation(data: ConsultCreate, db: Session = Depends(get_db)):
    consult = Consultation(
        patient_id  = data.patient_id,
        doctor_name = data.doctor_name,
        ai_summary  = data.ai_summary,
        status      = "pending",
    )
    db.add(consult)
    db.commit()
    db.refresh(consult)
    return {
        "status":          "success",
        "message":         f"Consultation request sent to {data.doctor_name}",
        "consultation_id": consult.id,
    }


# GET /consult/{patient_id} — Patient sees their own requests

@router.get("/{patient_id}")
def get_consultations_for_patient(
    patient_id: int, db: Session = Depends(get_db)
):
    consultations = db.query(Consultation).filter(
        Consultation.patient_id == patient_id
    ).order_by(Consultation.created_at.desc()).all()

    return [
        {
            "id":          c.id,
            "doctor_name": c.doctor_name,
            "status":      c.status,
            "ai_summary":  c.ai_summary,
            "created_at":  c.created_at.isoformat() if c.created_at else None,
        }
        for c in consultations
    ]


# GET /consult/doctor/{doctor_name} — Doctor sees all requests for them
# Returns each consultation enriched with patient profile, vitals, and labs.

@router.get("/doctor/{doctor_name}")
def get_consultations_for_doctor(
    doctor_name: str, db: Session = Depends(get_db)
):
    consultations = db.query(Consultation).filter(
        Consultation.doctor_name == doctor_name
    ).order_by(Consultation.created_at.desc()).all()

    return [_build_consultation_detail(c, db) for c in consultations]


# PUT /consult/{consult_id}/status — Doctor accepts or rejects

class StatusUpdate(BaseModel):
    status: str
    notes: str = ""

@router.put("/{consult_id}/status")
def update_consultation_status(
    consult_id: int,
    data: StatusUpdate,
    db: Session = Depends(get_db),
):
    consult = db.query(Consultation).filter(
        Consultation.id == consult_id
    ).first()

    if not consult:
        raise HTTPException(status_code=404, detail="Consultation not found")

    if data.status not in ["accepted", "rejected", "pending", "completed"]:
        raise HTTPException(
            status_code=400,
            detail="Status must be: accepted, rejected, pending, or completed"
        )

    consult.status = data.status
    db.commit()

    return {
        "status":  "success",
        "message": f"Consultation {data.status}",
        "id":      consult_id,
    }