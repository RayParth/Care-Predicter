from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    role = Column(String)
    gender = Column(String, nullable=True)
    age = Column(Integer, nullable=True)
    weight = Column(Float, nullable=True)
    height = Column(Float, nullable=True)
    blood_group = Column(String, nullable=True)
    password_hash = Column(String, nullable=True)
    email_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    vitals = relationship("Vital", back_populates="user")
    lab_reports = relationship("LabReport", back_populates="user")

class Vital(Base):
    __tablename__ = "vitals"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    heart_rate = Column(Float)
    spo2 = Column(Float)
    steps = Column(Integer)
    calories = Column(Float)
    sleep_hours = Column(Float)
    temperature = Column(Float)
    recorded_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="vitals")

class LabReport(Base):
    __tablename__ = "lab_reports"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    lab_name = Column(String)
    report_date = Column(String)
    # Core values
    glucose = Column(Float, nullable=True)
    hemoglobin = Column(Float, nullable=True)
    cholesterol = Column(Float, nullable=True)
    triglycerides = Column(Float, nullable=True)
    creatinine = Column(Float, nullable=True)
    uric_acid = Column(Float, nullable=True)
    wbc = Column(Float, nullable=True)
    platelets = Column(Float, nullable=True)
    rbc = Column(Float, nullable=True)
    # Extended values
    bilirubin = Column(Float, nullable=True)
    sgpt = Column(Float, nullable=True)
    sgot = Column(Float, nullable=True)
    hba1c = Column(Float, nullable=True)
    tsh = Column(Float, nullable=True)
    vitamin_d = Column(Float, nullable=True)
    vitamin_b12 = Column(Float, nullable=True)
    sodium = Column(Float, nullable=True)
    potassium = Column(Float, nullable=True)
    calcium = Column(Float, nullable=True)
    ldl = Column(Float, nullable=True)
    hdl = Column(Float, nullable=True)
    raw_text = Column(Text, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    user = relationship("User", back_populates="lab_reports")

class Consultation(Base):
    __tablename__ = "consultations"
    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("users.id"))
    doctor_name = Column(String)
    ai_summary = Column(Text)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

class Alert(Base):
    __tablename__ = "alerts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    parameter = Column(String)
    value = Column(String)
    message = Column(Text)
    triggered_at = Column(DateTime, default=datetime.utcnow)

class OtpCode(Base):
    __tablename__ = "otp_codes"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True)
    code = Column(String)
    expires_at = Column(DateTime)
    used = Column(Boolean, default=False)