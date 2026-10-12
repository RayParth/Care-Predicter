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

    # Railway/Render/Heroku-style URLs sometimes start with "postgres://",
    # which SQLAlchemy 2.x rejects. Normalise to "postgresql://".
    DATABASE_URL: str = (os.getenv("DATABASE_URL", "") or "").replace(
        "postgres://", "postgresql://", 1
    )

    # FIXED: crashes on startup if SECRET_KEY is missing — no insecure default
    SECRET_KEY: str = _require_env("SECRET_KEY")

    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    # Firebase project id (android/app/google-services.json -> "project_id").
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")
    # When true, /auth/google-login and /auth/register must carry a valid
    # Firebase ID token. Default: on in production, off elsewhere.
    REQUIRE_FIREBASE_TOKEN: bool = os.getenv(
        "REQUIRE_FIREBASE_TOKEN",
        "true" if os.getenv("ENV", "development").lower() == "production" else "false",
    ).lower() in ("1", "true", "yes")

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
    TEMP_LOW: float = 35.0             # mild hypothermia
    TEMP_CRITICAL_LOW: float = 32.0    # moderate/severe hypothermia — immediate attention

    VITALS_HISTORY_LIMIT: int = 10
    LAB_HISTORY_LIMIT: int = 20

    # CORS: comma-separated list in .env, e.g.
    # CORS_ORIGINS=https://your-app.railway.app,http://localhost:3000
    # Empty in dev is fine since a Flutter mobile client doesn't send an
    # Origin header the way a browser does — this matters if you ever add
    # a web admin/doctor dashboard. Do NOT ship "*" with allow_credentials=True
    # to production; browsers reject it and it's bad practice regardless.
    # AI - Gemini
    GEMINI_API_KEY: str = os.getenv(
        "GEMINI_API_KEY",
        ""
    )

    # gemini-2.5-flash has a published shutdown date of 16 Oct 2026 (and some
    # keys already get 404). Default to a Gemini 3.x model, keep it in env so a
    # future retirement is a config change, not a code change.
    GEMINI_MODEL: str = os.getenv(
        "GEMINI_MODEL",
        "gemini-3.5-flash"
    )

    # Comma-separated, tried in order if the primary returns 404/NOT_FOUND.
    GEMINI_FALLBACK_MODELS: list = [
        m.strip()
        for m in os.getenv("GEMINI_FALLBACK_MODELS", "gemini-3.1-flash-lite").split(",")
        if m.strip()
    ]

    # Per-user AI chat limits (in-memory; fine for a single container).
    AI_RATE_LIMIT_PER_MINUTE: int = int(os.getenv("AI_RATE_LIMIT_PER_MINUTE", "10"))
    AI_RATE_LIMIT_PER_DAY: int = int(os.getenv("AI_RATE_LIMIT_PER_DAY", "150"))

    GEMINI_TIMEOUT_SECONDS: int = int(
        os.getenv(
            "GEMINI_TIMEOUT_SECONDS",
            "60"
        )
    )

    CORS_ORIGINS: list = [
        o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()
    ]


settings = Settings()

# Fail fast in production instead of booting a half-working server.
if settings.ENV.lower() == "production":
    if not settings.DATABASE_URL:
        raise RuntimeError("DATABASE_URL must be set when ENV=production")
    if not settings.REQUIRE_FIREBASE_TOKEN:
        raise RuntimeError("REQUIRE_FIREBASE_TOKEN must be true in production")
    if not settings.FIREBASE_PROJECT_ID:
        raise RuntimeError("FIREBASE_PROJECT_ID must be set in production")
    if len(settings.SECRET_KEY) < 32:
        raise RuntimeError("SECRET_KEY must be at least 32 characters in production")
    if not settings.CORS_ORIGINS:
        print("[config] WARNING: CORS_ORIGINS is empty. Fine for a mobile-only "
              "client, but any web client will be blocked.")