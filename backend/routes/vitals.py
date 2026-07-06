from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import Vital, Alert, User
from schemas import VitalCreate, VitalResponse
from config import settings
from security import get_current_user, require_self_or_doctor

router = APIRouter(prefix="/vitals", tags=["vitals"])


def check_thresholds(vital: VitalCreate, db: Session):
    """
    All thresholds come from settings (config.py).
    To change any threshold: edit config.py only.
    """
    alerts = []

    def _add_alert(param: str, value: str, msg: str):
        a = Alert(user_id=vital.user_id, parameter=param, value=value, message=msg)
        db.add(a)
        alerts.append(a)

    # SpO2 check
    if vital.spo2 > 0:
        if vital.spo2 < settings.SPO2_CRITICAL:
            _add_alert("SpO\u2082", f"{vital.spo2}%", "Sp\u04502 critically low \u2014 immediate attention needed")
        elif vital.spo2 < settings.SPO2_LOW:
            _add_alert("SpO\u2082", f"{vital.spo2}%", "Sp\u04502 below safe threshold")

    # Heart rate check
    if vital.heart_rate > 0:
        if vital.heart_rate > settings.HR_CRITICAL_HIGH:
            _add_alert("Heart rate", f"{vital.heart_rate} bpm", "Heart rate critically high")
        elif vital.heart_rate > settings.HR_HIGH or vital.heart_rate < settings.HR_LOW:
            _add_alert("Heart rate", f"{vital.heart_rate} bpm", "Heart rate out of safe range")

    # Temperature check
    if vital.temperature > 0:
        if vital.temperature > settings.TEMP_CRITICAL:
            _add_alert("Temperature", f"{vital.temperature}\u00b0C", "High fever detected")
        elif vital.temperature > settings.TEMP_HIGH:
            _add_alert("Temperature", f"{vital.temperature}\u00b0C", "Elevated body temperature")

    if alerts:
        db.commit()
    return alerts


@router.post("/", response_model=VitalResponse)
def save_vitals(
    vital: VitalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # A logged-in patient can only write vitals under their own user_id.
    # Without this check, patient A's token could write into patient B's record
    # by just changing the user_id in the request body.
    if vital.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot save vitals for another user.")

    new_vital = Vital(**vital.dict())
    db.add(new_vital)
    db.commit()
    db.refresh(new_vital)
    check_thresholds(vital, db)
    return new_vital


@router.get("/{user_id}", response_model=List[VitalResponse])
def get_vitals(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_self_or_doctor(user_id, current_user)
    vitals = (
        db.query(Vital)
        .filter(Vital.user_id == user_id)
        .order_by(Vital.recorded_at.desc())
        .limit(settings.VITALS_HISTORY_LIMIT)
        .all()
    )
    return vitals


@router.get("/{user_id}/latest", response_model=VitalResponse)
def get_latest_vital(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_self_or_doctor(user_id, current_user)
    vital = (
        db.query(Vital)
        .filter(Vital.user_id == user_id)
        .order_by(Vital.recorded_at.desc())
        .first()
    )
    if not vital:
        raise HTTPException(status_code=404, detail="No vitals found")
    return vital