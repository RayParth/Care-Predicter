from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any
from datetime import datetime

class UserCreate(BaseModel):
    email: str
    name: str
    role: str
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

class VitalCreate(BaseModel):
    user_id: int
    heart_rate: float
    spo2: float
    steps: int
    calories: float
    sleep_hours: float
    temperature: float

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