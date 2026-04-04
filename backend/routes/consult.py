from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import Consultation
from schemas import ConsultCreate

router = APIRouter(prefix="/consult", tags=["consult"])

@router.post("/")
def create_consultation(data: ConsultCreate, db: Session = Depends(get_db)):
    consult = Consultation(
        patient_id=data.patient_id,
        doctor_name=data.doctor_name,
        ai_summary=data.ai_summary,
        status="pending"
    )
    db.add(consult)
    db.commit()
    db.refresh(consult)
    return {
        "status": "success",
        "message": f"Consultation request sent to {data.doctor_name}",
        "consultation_id": consult.id
    }

@router.get("/{patient_id}")
def get_consultations(patient_id: int, db: Session = Depends(get_db)):
    consultations = db.query(Consultation).filter(
        Consultation.patient_id == patient_id
    ).all()
    return consultations