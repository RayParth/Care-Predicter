# backend/config.py — every setting in one place
import os
from dotenv import load_dotenv
load_dotenv()

class Settings:
    APP_NAME: str = "Care Predicter API"
    APP_VERSION: str = "1.0.0"
    ENV: str = os.getenv("ENV", "development")

    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "CHANGE_THIS_IN_PRODUCTION")
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

    SPO2_CRITICAL: float = 90.0
    SPO2_LOW: float = 92.0
    HR_CRITICAL_HIGH: float = 130.0
    HR_HIGH: float = 120.0
    HR_LOW: float = 40.0
    TEMP_CRITICAL: float = 39.0
    TEMP_HIGH: float = 38.5

    VITALS_HISTORY_LIMIT: int = 10
    LAB_HISTORY_LIMIT: int = 20

settings = Settings()