import random
import string
import hashlib
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import User, OtpCode
from schemas import UserCreate, UserResponse, UserLogin, OtpRequest, OtpVerify
import smtplib
from email.mime.text import MIMEText
import os

router = APIRouter(prefix="/auth", tags=["auth"])


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def generate_otp() -> str:
    return ''.join(random.choices(string.digits, k=6))


def send_otp_email(email: str, otp: str):
    """Send OTP via Gmail SMTP. Set env vars SMTP_EMAIL and SMTP_PASSWORD."""
    smtp_email = os.getenv("SMTP_EMAIL", "")
    smtp_password = os.getenv("SMTP_PASSWORD", "")

    if not smtp_email or not smtp_password:
        # In development — just print the OTP
        print(f"[DEV] OTP for {email}: {otp}")
        return

    try:
        msg = MIMEText(
            f"Your Care Predicter verification code is: {otp}\n\nThis code expires in 10 minutes."
        )
        msg['Subject'] = 'Care Predicter — Verification Code'
        msg['From'] = smtp_email
        msg['To'] = email

        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(smtp_email, smtp_password)
            smtp.send_message(msg)
    except Exception as e:
        print(f"Email send failed: {e}")
        print(f"[FALLBACK] OTP for {email}: {otp}")


# ── Gmail OAuth registration (existing flow) ─────────────────────────────

@router.post("/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        # Update profile fields if they changed
        if user.name: existing.name = user.name
        if user.gender: existing.gender = user.gender
        if user.age: existing.age = user.age
        if user.weight: existing.weight = user.weight
        if user.height: existing.height = user.height
        if user.blood_group: existing.blood_group = user.blood_group
        db.commit()
        db.refresh(existing)
        return existing

    new_user = User(
        email=user.email,
        name=user.name,
        role=user.role,
        gender=user.gender,
        age=user.age,
        weight=user.weight,
        height=user.height,
        blood_group=user.blood_group,
        email_verified=True,  # Gmail OAuth = already verified
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ── Email + Password registration ────────────────────────────────────────

@router.post("/register-email", response_model=UserResponse)
def register_with_email(user: UserCreate, db: Session = Depends(get_db)):
    if not user.password:
        raise HTTPException(status_code=400, detail="Password is required")

    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered. Please login.")

    new_user = User(
        email=user.email,
        name=user.name,
        role=user.role,
        password_hash=hash_password(user.password),
        gender=user.gender,
        age=user.age,
        weight=user.weight,
        height=user.height,
        blood_group=user.blood_group,
        email_verified=False,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ── Email + Password login ───────────────────────────────────────────────

@router.post("/login-email", response_model=UserResponse)
def login_with_email(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    if not user.password_hash:
        raise HTTPException(status_code=400, detail="This account uses Gmail login. Please sign in with Google.")

    if user.password_hash != hash_password(credentials.password):
        raise HTTPException(status_code=401, detail="Incorrect password")

    return user


# ── Send OTP ─────────────────────────────────────────────────────────────

@router.post("/send-otp")
def send_otp(request: OtpRequest, db: Session = Depends(get_db)):
    # Delete old OTPs for this email
    db.query(OtpCode).filter(OtpCode.email == request.email).delete()
    db.commit()

    otp = generate_otp()
    expires = datetime.utcnow() + timedelta(minutes=10)

    otp_record = OtpCode(
        email=request.email,
        code=otp,
        expires_at=expires,
    )
    db.add(otp_record)
    db.commit()

    send_otp_email(request.email, otp)

    return {"status": "sent", "message": f"OTP sent to {request.email}"}


# ── Verify OTP ───────────────────────────────────────────────────────────

@router.post("/verify-otp")
def verify_otp(data: OtpVerify, db: Session = Depends(get_db)):
    record = db.query(OtpCode).filter(
        OtpCode.email == data.email,
        OtpCode.used == False,
    ).order_by(OtpCode.id.desc()).first()

    if not record:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")

    if datetime.utcnow() > record.expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")

    if record.code != data.code:
        raise HTTPException(status_code=400, detail="Incorrect OTP.")

    record.used = True

    # Mark user as verified
    user = db.query(User).filter(User.email == data.email).first()
    if user:
        user.email_verified = True

    db.commit()

    return {"status": "verified", "message": "Email verified successfully"}


# ── Get user by email ────────────────────────────────────────────────────

@router.get("/user/{email}", response_model=UserResponse)
def get_user(email: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── Get user profile with all data ──────────────────────────────────────

@router.get("/profile/{user_id}", response_model=UserResponse)
def get_profile(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── Update profile ───────────────────────────────────────────────────────

@router.put("/profile/{user_id}", response_model=UserResponse)
def update_profile(user_id: int, data: UserCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if data.name: user.name = data.name
    if data.gender: user.gender = data.gender
    if data.age: user.age = data.age
    if data.weight: user.weight = data.weight
    if data.height: user.height = data.height
    if data.blood_group: user.blood_group = data.blood_group

    db.commit()
    db.refresh(user)
    return user