from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import List

from sqlalchemy.exc import IntegrityError

from database import get_db
from models import Vital, Alert, User
from schemas import VitalBatch, VitalCreate, VitalResponse
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
            _add_alert("SpO\u2082", f"{vital.spo2}%", "SpO2 critically low \u2014 immediate attention needed")
        elif vital.spo2 < settings.SPO2_LOW:
            _add_alert("SpO\u2082", f"{vital.spo2}%", "SpO2 below safe threshold")

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
        elif vital.temperature < settings.TEMP_CRITICAL_LOW:
            _add_alert("Temperature", f"{vital.temperature}\u00b0C", "Severe hypothermia \u2014 immediate attention needed")
        elif vital.temperature < settings.TEMP_LOW:
            _add_alert("Temperature", f"{vital.temperature}\u00b0C", "Low body temperature detected")

    if alerts:
        db.commit()
    return alerts


ALERT_MAX_AGE = timedelta(minutes=60)   # don't raise "critical NOW" for a 6-hour-old reading
MAX_FUTURE_SKEW = timedelta(minutes=5)


def _clean_time(ts: datetime | None) -> datetime | None:
    """Store naive UTC. Reject timestamps from the future (bad phone clock)."""
    if ts is None:
        return None
    if ts.tzinfo is not None:
        ts = ts.astimezone(timezone.utc).replace(tzinfo=None)
    if ts > datetime.utcnow() + MAX_FUTURE_SKEW:
        raise HTTPException(status_code=422, detail="recorded_at is in the future.")
    return ts


def _insert_vital(vital: VitalCreate, db: Session):
    """Insert one reading. Returns (row, created). Re-sending the same
    client_id returns the existing row instead of creating a duplicate."""
    data = {k: v for k, v in vital.model_dump().items() if v is not None}
    ts = _clean_time(vital.recorded_at)
    if ts is not None:
        data["recorded_at"] = ts
    row = Vital(**data)
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = (
            db.query(Vital)
            .filter(Vital.user_id == vital.user_id, Vital.client_id == vital.client_id)
            .first()
        )
        if existing is None:
            raise
        return existing, False
    db.refresh(row)
    age = datetime.utcnow() - (row.recorded_at or datetime.utcnow())
    if age <= ALERT_MAX_AGE:
        check_thresholds(vital, db)
    return row, True


@router.post("/", response_model=VitalResponse)
def save_vitals(
    vital: VitalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # A logged-in patient can only write vitals under their own user_id.
    if vital.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot save vitals for another user.")
    row, _ = _insert_vital(vital, db)
    return row


@router.post("/batch")
def save_vitals_batch(
    batch: VitalBatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Offline sync: the app queues readings while offline and flushes them here.
    Safe to retry: every item with a client_id is applied at most once.
    Response lists what the app may now delete from its local queue."""
    if any(v.user_id != current_user.id for v in batch.items):
        raise HTTPException(status_code=403, detail="Cannot save vitals for another user.")

    accepted, duplicates, rejected = [], [], []
    for i, item in enumerate(batch.items):
        key = item.client_id or f"#{i}"
        try:
            _, created = _insert_vital(item, db)
            (accepted if created else duplicates).append(key)
        except HTTPException as exc:
            rejected.append({"client_id": key, "reason": exc.detail})
        except Exception as exc:  # noqa: BLE001
            db.rollback()
            rejected.append({"client_id": key, "reason": str(exc)[:200]})
    return {"accepted": accepted, "duplicates": duplicates, "rejected": rejected}


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