from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class UserCreate(BaseModel):
    email: str
    name: str
    role: str

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    class Config:
        from_attributes = True

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
    lab_name: Optional[str]
    report_date: Optional[str]
    glucose: Optional[float]
    hemoglobin: Optional[float]
    cholesterol: Optional[float]
    triglycerides: Optional[float]
    creatinine: Optional[float]
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