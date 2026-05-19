# backend/security.py — all auth/crypto logic
# FIXED: replaced SHA-256 with bcrypt (SHA-256 is not a password hashing algorithm)
import bcrypt
import secrets
import string
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from config import settings


def hash_password(password: str) -> str:
    """Hash a password using bcrypt with cost factor 12."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plain password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def generate_otp() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(settings.OTP_LENGTH))


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    payload = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload.update({"exp": expire, "iat": datetime.utcnow()})
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None