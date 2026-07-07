from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Consultation, User, Vital, LabReport
from schemas import ConsultCreate
from pydantic import BaseModel
from security import get_current_user, require_self_or_doctor

router = APIRouter(prefix="/consult", tags=["consult"])


# ── Helper: build full patient data for a consultation ────────────────────────

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


# ── POST /consult/ — Patient creates a consultation request ──────────────────
# FIXED: Added duplicate prevention — no more spamming the same doctor

@router.post("/")
def create_consultation(
    data: ConsultCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if data.patient_id != current_user.id:
        raise HTTPException(status_code=403, detail="Cannot file a consultation request as another user.")

    # Prevent duplicate pending requests to the same doctor
    existing = db.query(Consultation).filter(
        Consultation.patient_id == data.patient_id,
        Consultation.doctor_name == data.doctor_name,
        Consultation.status == "pending",
    ).first()

    if existing:
        raise HTTPException(
            status_code=400,
            detail="You already have a pending request to this doctor. Wait for a response first."
        )

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


# ── IMPORTANT: Specific routes MUST come before parameterized routes ──────────
# FIXED: /consult/doctor/{doctor_name} was BELOW /consult/{patient_id}
# FastAPI matched "doctor" as a patient_id integer, causing 422 errors on the
# doctor dashboard. Specific path first, parameterized path after.


# ── GET /consult/doctor/{doctor_name} — Doctor sees all requests for them ─────

@router.get("/doctor/{doctor_name}")
def get_consultations_for_doctor(
    doctor_name: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # NOTE — real design flaw, not fully fixed here: consultations are keyed
    # by doctor_name (a string), not doctor_id (a foreign key). This check
    # only confirms the caller IS a doctor and their own name matches the
    # path param. It does NOT stop Doctor A from setting their `name` field
    # to "Dr. B" and pulling Dr. B's consultation queue — the schema has no
    # way to tell two doctors with the same display name apart, or to stop
    # a doctor from renaming themselves to impersonate another.
    # Real fix: add doctor_id (ForeignKey to users.id) on Consultation and
    # route by ID, not by name. That's a migration, not a one-line patch —
    # flagging it here instead of pretending this closes the gap.
    if current_user.role != "doctor" or current_user.name != doctor_name:
        raise HTTPException(status_code=403, detail="Not authorized for this doctor's queue.")

    consultations = db.query(Consultation).filter(
        Consultation.doctor_name == doctor_name
    ).order_by(Consultation.created_at.desc()).all()

    return [_build_consultation_detail(c, db) for c in consultations]


# ── GET /consult/{patient_id} — Patient sees their own requests ───────────────

@router.get("/{patient_id}")
def get_consultations_for_patient(
    patient_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_self_or_doctor(patient_id, current_user)
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


# ── PUT /consult/{consult_id}/status — Doctor accepts or rejects ──────────────

class StatusUpdate(BaseModel):
    status: str   # "accepted" or "rejected"
    notes: str = ""

@router.put("/{consult_id}/status")
def update_consultation_status(
    consult_id: int,
    data: StatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Only doctors can update consultation status.")

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