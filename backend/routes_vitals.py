from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Vital, Alert
from schemas import VitalCreate, VitalResponse
from typing import List
from datetime import datetime

router = APIRouter(prefix="/vitals", tags=["vitals"])

# Threshold rules — fallback when AI is offline
THRESHOLDS = {
    "spo2": {"min": 92, "message": "SpO₂ dropped below safe threshold"},
    "heart_rate": {"max": 120, "min": 40, "message": "Heart rate out of safe range"},
    "temperature": {"max": 38.5, "message": "High body temperature detected"},
}

def check_thresholds(vital: VitalCreate, db: Session):
    alerts = []
    if vital.spo2 < THRESHOLDS["spo2"]["min"]:
        alert = Alert(
            user_id=vital.user_id,
            parameter="SpO₂",
            value=f"{vital.spo2}%",
            message=THRESHOLDS["spo2"]["message"],
        )
        db.add(alert)
        alerts.append(alert)
    if vital.heart_rate > THRESHOLDS["heart_rate"]["max"] or \
       vital.heart_rate < THRESHOLDS["heart_rate"]["min"]:
        alert = Alert(
            user_id=vital.user_id,
            parameter="Heart rate",
            value=f"{vital.heart_rate} bpm",
            message=THRESHOLDS["heart_rate"]["message"],
        )
        db.add(alert)
        alerts.append(alert)
    if vital.temperature > THRESHOLDS["temperature"]["max"]:
        alert = Alert(
            user_id=vital.user_id,
            parameter="Temperature",
            value=f"{vital.temperature}°C",
            message=THRESHOLDS["temperature"]["message"],
        )
        db.add(alert)
        alerts.append(alert)
    if alerts:
        db.commit()
    return alerts

@router.post("/", response_model=VitalResponse)
def save_vitals(vital: VitalCreate, db: Session = Depends(get_db)):
    new_vital = Vital(**vital.dict())
    db.add(new_vital)
    db.commit()
    db.refresh(new_vital)
    alerts = check_thresholds(vital, db)
    return new_vital

@router.get("/{user_id}", response_model=List[VitalResponse])
def get_vitals(user_id: int, db: Session = Depends(get_db)):
    vitals = db.query(Vital).filter(
        Vital.user_id == user_id
    ).order_by(Vital.recorded_at.desc()).limit(10).all()
    return vitals

@router.get("/{user_id}/latest", response_model=VitalResponse)
def get_latest_vital(user_id: int, db: Session = Depends(get_db)):
    vital = db.query(Vital).filter(
        Vital.user_id == user_id
    ).order_by(Vital.recorded_at.desc()).first()
    if not vital:
        raise HTTPException(status_code=404, detail="No vitals found")
    return vital