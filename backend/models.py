from sqlalchemy import Column, Integer, String, Float, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    role = Column(String)  # 'patient' or 'doctor'
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
    glucose = Column(Float)
    hemoglobin = Column(Float)
    cholesterol = Column(Float)
    triglycerides = Column(Float)
    creatinine = Column(Float)
    uric_acid = Column(Float)
    wbc = Column(Float)
    platelets = Column(Float)
    raw_text = Column(Text)
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