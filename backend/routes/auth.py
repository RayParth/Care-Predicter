import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import User, OtpCode
from schemas import UserCreate, UserResponse, UserLogin, OtpRequest, OtpVerify
from config import settings
from security import (
    hash_password, verify_password, generate_otp, create_access_token,
    get_current_user, require_self_or_doctor,
)

router = APIRouter(prefix="/auth", tags=["auth"])


# OTP Email Delivery

def _send_otp_email(to_email: str, otp: str, subject: str = None, body: str = None) -> bool:
    if not settings.SMTP_EMAIL or not settings.SMTP_PASSWORD:
        print(f"\n{'='*50}")
        print(f"[DEV MODE] OTP for {to_email}: {otp}")
        print(f"{'='*50}\n")
        return False

    if body is None:
        body = (
            f"Hello,\n\n"
            f"Your Care Predicter verification code is:\n\n"
            f"        {otp}\n\n"
            f"This code expires in {settings.OTP_EXPIRY_MINUTES} minutes.\n\n"
            f"If you did not request this, please ignore this email.\n\n"
            f"— Care Predicter Team"
        )
    if subject is None:
        subject = "Care Predicter — Verification Code"

    msg = MIMEMultipart()
    msg["Subject"] = subject
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
            print(f"[EMAIL] Both failed: {tls_err}")
            print(f"[FALLBACK] OTP for {to_email}: {otp}")
            return False


def _send_otp_sms(phone: str, otp: str) -> bool:
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


# Helper

def _user_dict(user: User) -> dict:
    return {
        "id":           user.id,
        "email":        user.email,
        "name":         user.name,
        "role":         user.role,
        "gender":       user.gender,
        "age":          user.age,
        "weight":       user.weight,
        "height":       user.height,
        "blood_group":  user.blood_group,
        "has_password": user.password_hash is not None,
    }


# Google Login / Check
# Called by Flutter right after Firebase Google sign-in.
# Returns needs_registration:false + token + profile if user exists.
# Returns needs_registration:true if brand new user.

@router.post("/google-login")
def google_login(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        access_token = create_access_token({"sub": existing.email})
        return {
            "needs_registration": False,
            "access_token":       access_token,
            "user":               _user_dict(existing),
        }
    else:
        return {
            "needs_registration": True,
            "email": user.email,
            "name":  user.name,
        }


# Google Full Registration
# Called from ProfileSetupScreen after new Google user fills their profile.
# password is optional — if set, user can also login with email+password.

@router.post("/register")
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        for field in ["name", "gender", "age", "weight", "height", "blood_group"]:
            val = getattr(user, field, None)
            if val:
                setattr(existing, field, val)
        if user.password:
            existing.password_hash = hash_password(user.password)
        db.commit()
        db.refresh(existing)
        access_token = create_access_token({"sub": existing.email})
        return {"access_token": access_token, **_user_dict(existing)}

    new_user = User(
        email          = user.email,
        name           = user.name,
        role           = "patient",
        gender         = user.gender,
        age            = user.age,
        weight         = user.weight,
        height         = user.height,
        blood_group    = user.blood_group,
        email_verified = True,
        password_hash  = hash_password(user.password) if user.password else None,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    access_token = create_access_token({"sub": new_user.email})
    return {"access_token": access_token, **_user_dict(new_user)}


# Email + Password Registration

@router.post("/register-email", response_model=UserResponse)
def register_with_email(user: UserCreate, db: Session = Depends(get_db)):
    if not user.password:
        raise HTTPException(status_code=400, detail="Password is required")

    existing = db.query(User).filter(User.email == user.email).first()
    if existing:
        if existing.password_hash is None:
            raise HTTPException(
                status_code=400,
                detail="This email is already linked to a Google account. Please login with Google."
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


# Email + Password Login
# Google users can login here if they set a password during registration.

@router.post("/login-email")
def login_with_email(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email")

    if not user.password_hash:
        raise HTTPException(
            status_code=400,
            detail="This account uses Google login and has no password set. Please sign in with Google."
        )

    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect password")

    access_token = create_access_token({"sub": user.email})
    return {"access_token": access_token, "user": _user_dict(user)}


# Set Password
# Existing Google users call this to add a password to their account.

class SetPasswordRequest(BaseModel):
    email:    str
    password: str

@router.post("/set-password")
def set_password(data: SetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    user.password_hash = hash_password(data.password)
    db.commit()
    return {"status": "success", "message": "Password set successfully."}


# Forgot Password — Step 1: Send OTP

class ForgotPasswordRequest(BaseModel):
    email: str

@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        # Always return success — do not reveal whether email exists
        return {"status": "sent", "message": "If this email is registered, a reset code has been sent."}

    if user.password_hash is None:
        raise HTTPException(
            status_code=400,
            detail="This account uses Google login. No password to reset. Please sign in with Google."
        )

    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    recent_count = db.query(OtpCode).filter(
        OtpCode.email      == data.email,
        OtpCode.created_at >= one_hour_ago,
    ).count()

    if recent_count >= 3:
        raise HTTPException(
            status_code=429,
            detail="Too many reset requests. Please wait before trying again."
        )

    db.query(OtpCode).filter(OtpCode.email == data.email).delete()
    db.commit()

    otp     = generate_otp()
    expires = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
    db.add(OtpCode(email=data.email, code=otp, expires_at=expires))
    db.commit()

    reset_body = (
        f"Hello {user.name},\n\n"
        f"You requested a password reset for your Care Predicter account.\n\n"
        f"Your reset code is:\n\n"
        f"        {otp}\n\n"
        f"This code expires in {settings.OTP_EXPIRY_MINUTES} minutes.\n\n"
        f"If you did not request this, your account is safe — ignore this email.\n\n"
        f"— Care Predicter Team"
    )
    _send_otp_email(
        data.email, otp,
        subject="Care Predicter — Password Reset Code",
        body=reset_body,
    )

    return {"status": "sent", "message": f"Password reset code sent to {data.email}"}


# Reset Password — Step 2: Verify OTP + Save New Password

class ResetPasswordRequest(BaseModel):
    email:        str
    otp:          str
    new_password: str

@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    record = db.query(OtpCode).filter(
        OtpCode.email == data.email,
        OtpCode.used  == False,
    ).order_by(OtpCode.id.desc()).first()

    if not record:
        raise HTTPException(status_code=400, detail="No reset code found. Please request a new one.")
    if datetime.utcnow() > record.expires_at:
        raise HTTPException(status_code=400, detail="Reset code has expired. Please request a new one.")
    if record.code != data.otp:
        raise HTTPException(status_code=400, detail="Incorrect reset code.")
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")

    record.used = True
    db.commit()

    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    user.password_hash = hash_password(data.new_password)
    db.commit()

    return {
        "status":  "success",
        "message": "Password reset successfully. You can now login with your new password.",
    }


# Send OTP (for registration)

@router.post("/send-otp")
def send_otp_endpoint(request: OtpRequest, db: Session = Depends(get_db)):
    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    recent_count = db.query(OtpCode).filter(
        OtpCode.email      == request.email,
        OtpCode.created_at >= one_hour_ago,
    ).count()

    if recent_count >= 5:
        raise HTTPException(
            status_code=429,
            detail="Too many OTP requests. Please wait before requesting again."
        )

    db.query(OtpCode).filter(OtpCode.email == request.email).delete()
    db.commit()

    otp     = generate_otp()
    expires = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
    db.add(OtpCode(email=request.email, code=otp, expires_at=expires))
    db.commit()

    sent = _send_otp_email(request.email, otp)
    return {"status": "sent", "message": f"OTP sent to {request.email}", "delivered": sent}


# Verify OTP

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

    record.used         = True
    db.commit()

    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found after OTP verification.")

    user.email_verified = True
    db.commit()

    access_token = create_access_token({"sub": user.email})
    return {
        "status":       "verified",
        "access_token": access_token,
        "user":         _user_dict(user),
    }


# Get User by Email

@router.get("/user/{email}", response_model=UserResponse)
def get_user(
    email: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # FIXED: this used to return any user's full profile (name, age, weight,
    # height, blood group) to anyone who could guess or enumerate an email —
    # no login required at all.
    if current_user.email != email and current_user.role != "doctor":
        raise HTTPException(status_code=403, detail="Not authorized for this resource.")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# Get Profile

@router.get("/profile/{user_id}", response_model=UserResponse)
def get_profile(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_self_or_doctor(user_id, current_user)
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# Update Profile
# FIXED: previously anyone could PUT any user_id and overwrite that person's
# name, age, weight, height, blood group with no auth at all.

@router.put("/profile/{user_id}", response_model=UserResponse)
def update_profile(
    user_id: int,
    data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Profile edits are self-only — a doctor should not silently overwrite a
    # patient's own profile fields, so no allow_doctor bypass here.
    require_self_or_doctor(user_id, current_user, allow_doctor=False)
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


# Get All Doctors
# Returns all registered users with role = doctor.
# Called by ConsultTab so patients see only real registered doctors.

@router.get("/doctors")
def get_all_doctors(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doctors = db.query(User).filter(User.role == "doctor").all()
    return [
        {
            "id":    d.id,
            "name":  d.name,
            "email": d.email,
            "initials": "".join(
                word[0].upper()
                for word in d.name.split()
                if word
            )[:2] if d.name else "DR",
        }
        for d in doctors
    ]