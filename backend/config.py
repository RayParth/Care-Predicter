# backend/config.py — every setting in one place
# FIXED: SECRET_KEY now raises an error on startup if not set in .env
#        instead of silently using a known default string that anyone can forge tokens with.
import os
from dotenv import load_dotenv

load_dotenv()


def _require_env(key: str) -> str:
    """Crash on startup if a required environment variable is missing."""
    val = os.getenv(key)
    if not val:
        raise RuntimeError(
            f"Required environment variable '{key}' is not set. "
            f"Add it to your .env file before starting the server."
        )
    return val


class Settings:
    APP_NAME: str = "Care Predicter API"
    APP_VERSION: str = "1.0.0"
    ENV: str = os.getenv("ENV", "development")

    DATABASE_URL: str = os.getenv("DATABASE_URL", "")

    # FIXED: crashes on startup if SECRET_KEY is missing — no insecure default
    SECRET_KEY: str = _require_env("SECRET_KEY")

    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    OTP_LENGTH: int = 6
    OTP_EXPIRY_MINUTES: int = 10
    OTP_RATE_LIMIT_PER_HOUR: int = 5

    SMTP_EMAIL: str = os.getenv("SMTP_EMAIL", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT_SSL: int = 465
    SMTP_PORT_TLS: int = 587

    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_FROM_NUMBER: str = os.getenv("TWILIO_FROM_NUMBER", "")

    # Health alert thresholds — match these with app_config.dart
    SPO2_CRITICAL: float = 90.0
    SPO2_LOW: float = 95.0        # FIXED: was 92.0, frontend uses 95.0 — now aligned
    HR_CRITICAL_HIGH: float = 130.0
    HR_HIGH: float = 100.0        # FIXED: was 120.0, frontend uses 100.0 — now aligned
    HR_LOW: float = 60.0          # FIXED: was 40.0, frontend uses 60.0 — now aligned
    TEMP_CRITICAL: float = 39.0
    TEMP_HIGH: float = 38.5

    VITALS_HISTORY_LIMIT: int = 10
    LAB_HISTORY_LIMIT: int = 20


settings = Settings()