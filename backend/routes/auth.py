import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import User, OtpCode
from schemas import UserCreate, UserResponse, UserLogin, OtpRequest, OtpVerify
from config import settings
from security import hash_password, verify_password, generate_otp, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])


# ── OTP Email Delivery ────────────────────────────────────────────────────────

def _send_otp_email(to_email: str, otp: str) -> bool:
    """Send OTP via Gmail SMTP. Returns True if actually sent."""
    if not settings.SMTP_EMAIL or not settings.SMTP_PASSWORD:
        print(f"\n{'='*50}")
        print(f"[DEV MODE] OTP for {to_email}: {otp}")
        print(f"[DEV MODE] Add SMTP_EMAIL + SMTP_PASSWORD to .env for real emails")
        print(f"{'='*50}\n")
        return False

    body = (
        f"Hello,\n\n"
        f"Your Care Predicter verification code is:\n\n"
        f"        {otp}\n\n"
        f"This code expires in {settings.OTP_EXPIRY_MINUTES} minutes.\n\n"
        f"If you did not request this, please ignore this email.\n\n"
        f"— Care Predicter Team"
    )

    msg = MIMEMultipart()
    msg["Subject"] = "Care Predicter — Verification Code"
    msg["From"]    = f"Care Predicter <{settings.SMTP_EMAIL}>"
    msg["To"]      = to_email
    msg.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT_SSL, timeout=15) as smtp:
            smtp.login(settings.SMTP_EMAIL, settings.SMTP_PASSWORD)
            smtp.send_message(msg)
            print(f"[EMAIL] OTP sent to {to_email} via SSL")
            return True
    except Exception as ssl_err:
        print(f"[EMAIL] SSL failed ({ssl_err}), trying TLS...")
        try:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT_TLS, timeout=15) as smtp:
                smtp.starttls()
                smtp.login(settings.SMTP_EMAIL, settings.SMTP_PASSWORD)
                smtp.send_message(msg)
                print(f"[EMAIL] OTP sent to {to_email} via TLS")
                return True
        except Exception as tls_err:
            print(f"[EMAIL] Both SSL and TLS failed: {tls_err}")
            print(f"[FALLBACK] OTP for {to_email}: {otp}")
            return False


def _send_otp_sms(phone: str, otp: str) -> bool:
    """Send OTP via Twilio SMS. Returns True if sent."""
    if not all([settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM_NUMBER]):
        print(f"[SMS] Twilio not configured — skipping SMS for {phone}")
        return False
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(
            body=(
                f"Care Predicter code: {otp}. "
                f"Expires in {settings.OTP_EXPIRY_MINUTES} min. Do not share."
            ),
            from_=settings.TWILIO_FROM_NUMBER,
            to=phone,
        )
        print(f"[SMS] OTP sent to {phone}")
        return True
    except Exception as e:
        print(f"[SMS] Failed: {e}")
        return False


# ── Google OAuth — Check or Register ─────────────────────────────────────────
#
# THIS IS THE NEW ENDPOINT.
# Flutter calls this immediately after Firebase Google sign-in succeeds.
#
# Logic:
#   - If email already exists in DB  →  return token + full profile
#     (user goes straight to dashboard, no registration screens)
#   - If email does NOT exist in DB  →  return needs_registration: true
#     (Flutter shows RoleSelectScreen → ProfileSetupScreen)
#
@router.post("/google-login")
def google_login(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()

    if existing:
        # User already in database — just return their data and a token
        access_token = create_access_token({"sub": existing.email})
        return {
            "needs_registration": False,
            "access_token": access_token,
            "user": {
                "id":          existing.id,
                "email":       existing.email,
                "name":        existing.name,
                "role":        existing.role,
                "gender":      existing.gender,
                "age":         existing.age,
                "weight":      existing.weight,
                "height":      existing.height,
                "blood_group": existing.blood_group,
            }
        }
    else:
        # New Google user — Flutter must collect role + profile first
        return {
            "needs_registration": True,
            "email": user.email,
            "name":  user.name,
        }


# ── Gmail OAuth Full Registration ─────────────────────────────────────────────
#
# Called from ProfileSetupScreen after new Google user fills their profile.
# This saves the full profile to the database.
#
@router.post("/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        # Update profile fields if provided
        for field in ["name", "gender", "age", "weight", "height", "blood_group", "role"]:
            val = getattr(user, field, None)
            if val:
                setattr(existing, field, val)
        db.commit()
        db.refresh(existing)
        return existing

    new_user = User(
        email          = user.email,
        name           = user.name,
        role           = user.role,
        gender         = user.gender,
        age            = user.age,
        weight         = user.weight,
        height         = user.height,
        blood_group    = user.blood_group,
        email_verified = True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ── Email + Password Registration ────────────────────────────────────────────

@router.post("/register-email", response_model=UserResponse)
def register_with_email(user: UserCreate, db: Session = Depends(get_db)):
    if not user.password:
        raise HTTPException(status_code=400, detail="Password is required")

    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        # Check if this email was registered via Google
        if existing.password_hash is None:
            raise HTTPException(
                status_code=400,
                detail="This email is already registered via Google login. Please use Sign in with Google."
            )
        raise HTTPException(status_code=400, detail="Email already registered. Please login.")

    new_user = User(
        email          = user.email,
        name           = user.name,
        role           = user.role,
        password_hash  = hash_password(user.password),
        gender         = user.gender,
        age            = user.age,
        weight         = user.weight,
        height         = user.height,
        blood_group    = user.blood_group,
        email_verified = False,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


# ── Email + Password Login ────────────────────────────────────────────────────

@router.post("/login-email")
def login_with_email(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    if not user.password_hash:
        raise HTTPException(
            status_code=400,
            detail="This account was created with Google login. Please tap 'Continue with Gmail' instead."
        )

    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect password")

    access_token = create_access_token({"sub": user.email})

    return {
        "access_token": access_token,
        "user": {
            "id":          user.id,
            "email":       user.email,
            "name":        user.name,
            "role":        user.role,
            "gender":      user.gender,
            "age":         user.age,
            "weight":      user.weight,
            "height":      user.height,
            "blood_group": user.blood_group,
        }
    }


# ── Send OTP ──────────────────────────────────────────────────────────────────

@router.post("/send-otp")
def send_otp_endpoint(request: OtpRequest, db: Session = Depends(get_db)):
    # FIXED: original code created one_hour_ago but never used it in the query
    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    recent_count = db.query(OtpCode).filter(
        OtpCode.email      == request.email,
        OtpCode.created_at >= one_hour_ago,   # ← this was the missing filter
    ).count()

    if recent_count >= 5:
        raise HTTPException(
            status_code=429,
            detail="Too many OTP requests. Please wait before requesting again."
        )

    # Delete all old OTPs for this email before creating a new one
    db.query(OtpCode).filter(OtpCode.email == request.email).delete()
    db.commit()

    otp     = generate_otp()
    expires = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)

    otp_record = OtpCode(
        email      = request.email,
        code       = otp,
        expires_at = expires,
    )
    db.add(otp_record)
    db.commit()

    sent = _send_otp_email(request.email, otp)

    return {
        "status":    "sent",
        "message":   f"OTP sent to {request.email}",
        "delivered": sent
    }


# ── Verify OTP ────────────────────────────────────────────────────────────────

@router.post("/verify-otp")
def verify_otp(data: OtpVerify, db: Session = Depends(get_db)):
    record = db.query(OtpCode).filter(
        OtpCode.email == data.email,
        OtpCode.used  == False,
    ).order_by(OtpCode.id.desc()).first()

    if not record:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")

    if datetime.utcnow() > record.expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")

    if record.code != data.code:
        raise HTTPException(status_code=400, detail="Incorrect OTP.")

    record.used = True
    db.commit()

    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found after OTP verification.")

    # Mark email as verified
    user.email_verified = True
    db.commit()

    access_token = create_access_token({"sub": user.email})

    return {
        "status":       "verified",
        "access_token": access_token,
        "user": {
            "id":          user.id,
            "email":       user.email,
            "name":        user.name,
            "role":        user.role,
            "gender":      user.gender,
            "age":         user.age,
            "weight":      user.weight,
            "height":      user.height,
            "blood_group": user.blood_group,
        }
    }


# ── Get User by Email ─────────────────────────────────────────────────────────

@router.get("/user/{email}", response_model=UserResponse)
def get_user(email: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── Get Profile ───────────────────────────────────────────────────────────────

@router.get("/profile/{user_id}", response_model=UserResponse)
def get_profile(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── Update Profile ────────────────────────────────────────────────────────────

@router.put("/profile/{user_id}", response_model=UserResponse)
def update_profile(user_id: int, data: UserCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    for field in ["name", "gender", "age", "weight", "height", "blood_group"]:
        val = getattr(data, field, None)
        if val:
            setattr(user, field, val)

    db.commit()
    db.refresh(user)
    return user