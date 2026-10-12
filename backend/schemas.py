from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Any, Dict, List, Optional
from datetime import datetime


class UserCreate(BaseModel):
    email: str
    name: str
    role: str
    id_token: Optional[str] = None   # Firebase ID token (required when REQUIRE_FIREBASE_TOKEN)
    password: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    weight: Optional[float] = None
    height: Optional[float] = None
    blood_group: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    gender: Optional[str] = None
    age: Optional[int] = None
    weight: Optional[float] = None
    height: Optional[float] = None
    blood_group: Optional[str] = None
    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    email: str
    password: str


class OtpRequest(BaseModel):
    email: str


class OtpVerify(BaseModel):
    email: str
    code: str


# FIXED: Added Field validators on all vital signs.
# Without these, anyone can POST heart_rate=9999 and trigger a fake critical alert
# for a real doctor. The backend was saving any number without complaint.
class VitalCreate(BaseModel):
    user_id: int

    # Offline sync support. recorded_at = when the reading was MEASURED on the
    # phone (not when it reached the server); client_id = a UUID the app makes
    # once per reading so retries can't create duplicates.
    recorded_at: Optional[datetime] = None
    client_id: Optional[str] = Field(default=None, max_length=64)

    heart_rate: float = Field(
        ...,
        ge=0,
        le=300,
        description="Heart rate in bpm. Must be 0–300."
    )

    spo2: float = Field(
        ...,
        ge=0,
        le=100,
        description="Blood oxygen %. Must be 0–100."
    )

    steps: int = Field(
        ...,
        ge=0,
        le=100_000,
        description="Step count. Must be 0–100,000."
    )

    calories: float = Field(
        ...,
        ge=0,
        le=10_000,
        description="Active calories burned. Must be 0–10,000."
    )

    sleep_hours: float = Field(
        ...,
        ge=0,
        le=24,
        description="Sleep duration in hours. Must be 0–24."
    )

    temperature: float = Field(
        ...,
        ge=0,
        le=45.0,
        description=(
            "Body temperature in Celsius. Bounds are physical-plausibility "
            "limits only. Medical classification happens in "
            "vitals.py check_thresholds, not here."
        )
    )


    @field_validator("temperature")
    @classmethod
    def _temp_zero_or_plausible(cls, v: float) -> float:
        # 0 means "no temperature reading" (most wearables don't record one).
        # Anything else must be physically plausible.
        if v != 0 and v < 20.0:
            raise ValueError("temperature must be 0 (not measured) or between 20 and 45 C")
        return v


class VitalBatch(BaseModel):
    items: List[VitalCreate] = Field(..., min_length=1, max_length=200)


class VitalResponse(BaseModel):
    id: int
    heart_rate: float
    spo2: float
    steps: int
    calories: float
    sleep_hours: float
    temperature: float
    recorded_at: datetime
    class Config:
        from_attributes = True


class LabReportResponse(BaseModel):
    id: int
    lab_name: Optional[str] = None
    report_date: Optional[str] = None
    extracted_data: Dict[str, Any] = Field(default_factory=dict)

    # Legacy fields kept so existing consumers do not break during migration.
    glucose: Optional[float] = None
    hemoglobin: Optional[float] = None
    cholesterol: Optional[float] = None
    triglycerides: Optional[float] = None
    creatinine: Optional[float] = None
    uric_acid: Optional[float] = None
    wbc: Optional[float] = None
    platelets: Optional[float] = None
    rbc: Optional[float] = None
    bilirubin: Optional[float] = None
    sgpt: Optional[float] = None
    sgot: Optional[float] = None
    hba1c: Optional[float] = None
    tsh: Optional[float] = None
    vitamin_d: Optional[float] = None
    vitamin_b12: Optional[float] = None
    sodium: Optional[float] = None
    potassium: Optional[float] = None
    calcium: Optional[float] = None
    ldl: Optional[float] = None
    hdl: Optional[float] = None
    uploaded_at: datetime

    class Config:
        from_attributes = True


class ConsultCreate(BaseModel):
    patient_id: int
    doctor_name: str
    ai_summary: str


class AlertCreate(BaseModel):
    user_id: int
    parameter: str
    value: str
    message: str