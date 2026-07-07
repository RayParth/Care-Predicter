# backend/security.py — all auth/crypto logic
# FIXED: replaced SHA-256 with bcrypt (SHA-256 is not a password hashing algorithm)
import bcrypt
import secrets
import string
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from config import settings
from database import get_db as _get_db_dependency

_bearer_scheme = HTTPBearer(auto_error=False)


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


# --------------------------------------------------------------------------
# THIS WAS THE MISSING PIECE.
# Tokens were generated on login/register and sent by the Flutter app on
# every request, but no route ever decoded or checked them. Any user_id
# could be read or written by anyone with no token at all.
#
# get_current_user is a FastAPI dependency: add it to any route that should
# require login. It decodes the bearer token, looks up the user, and raises
# 401 if the token is missing, malformed, expired, or points to a user that
# no longer exists.
# --------------------------------------------------------------------------

def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
    db: Session = Depends(_get_db_dependency),
):
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated. Missing bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token.")

    from models import User  # local import avoids circular import at module load time
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists.")

    return user


def require_self_or_doctor(user_id: int, current_user, allow_doctor: bool = True):
    """
    Call this inside a route after resolving current_user to enforce:
    the caller is either the owner of user_id, or (if allowed) a doctor.
    Raises 403 otherwise. This is NOT a FastAPI dependency — call it as a
    plain function inside the route body, after both values are known.
    """
    if current_user.id == user_id:
        return
    if allow_doctor and current_user.role == "doctor":
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized for this resource.")