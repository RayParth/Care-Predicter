# 🩺 Care-Predicter — AI-Assisted Health Monitoring App

> **Flutter · FastAPI · PostgreSQL · Android Health Connect · Tesseract OCR · Google Gemini**

Care-Predicter is a mobile health-monitoring platform. It reads wearable and phone health data through Android Health Connect, extracts values from uploaded lab reports using OCR and Gemini, raises rule-based alerts when vitals cross safe thresholds, and lets patients ask an AI assistant questions about their own health data. Doctors get a separate interface to follow their patients and consultation requests.

> **Disclaimer:** Care-Predicter is an academic project. It is not a medical device and does not provide medical diagnosis or treatment advice.

<!-- Add screenshots to docs/screenshots/ and link them here -->

---

## ✨ Features

### For patients
- **Health dashboard** — vitals such as heart rate, SpO2, body temperature and steps, synced from Android Health Connect.
- **Rule-based alerts** — the backend compares each new vital reading against configurable thresholds (SpO2, heart rate, temperature) and creates warning or critical alerts.
- **Lab report upload with OCR** — upload a photo or PDF of a lab report. PyMuPDF and Tesseract read the text, Gemini converts it into structured JSON, and the result is stored in PostgreSQL (JSONB).
- **AI health assistant** — ask questions in natural language. The backend calls Gemini with a safety-focused system prompt (no diagnosis, emergency escalation guidance, limited input and output size).
- **Offline AI fallback** — if the cloud assistant is unavailable, the app can fall back to an on-device Gemma model (`flutter_gemma`).
- **Organ map** — tappable body diagram that links health readings to organs.
- **Consultation requests** — request a remote consultation with a doctor.

### For doctors
- Separate dashboard with a patient list, patient alerts and incoming consultation requests.

### Accounts and security
- Email registration with **OTP verification** (email via SMTP, SMS via Twilio when configured) and password reset.
- **Google Sign-In** through Firebase Authentication.
- Passwords hashed with **bcrypt**; sessions use **JWT** (HS256, 7-day expiry).
- **Role-based access**: patient and doctor roles, with ownership checks so users can access only their own records.
- Input validation with **Pydantic** (for example, physiological ranges on vitals and size limits on AI chat input).
- Upload allowlist for lab reports (JPG, JPEG, PNG, PDF).
- Secrets are read from environment variables, and the server refuses to start without `SECRET_KEY`. API docs are disabled when `ENV=production`.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────┐
│  Presentation tier — Flutter (Android)            │
│  Auth · Dashboard · Organ map · Lab upload ·      │
│  AI chat · Consult · Doctor dashboard             │
└───────────────────┬──────────────────────────────┘
                    │ HTTPS REST + JWT (Dio)
┌───────────────────▼──────────────────────────────┐
│  Application tier — FastAPI (Uvicorn)             │
│  /auth · /vitals · /ocr · /consult · /ai          │
│  Pydantic validation · JWT auth · alert rules     │
└───────┬───────────────────────┬──────────────────┘
        │ SQLAlchemy ORM        │ HTTPS
┌───────▼──────────┐   ┌────────▼─────────────────┐
│  PostgreSQL      │   │  Google Gemini API        │
│  users · vitals  │   │  (assistant + OCR         │
│  lab_reports ·   │   │   text → structured JSON) │
│  consultations · │   └──────────────────────────┘
│  alerts · otp    │
└──────────────────┘

External services: Android Health Connect · Firebase Auth ·
Tesseract OCR · SMTP (email OTP) · Twilio (optional SMS OTP)
```

**Lab report flow**

```
Photo / PDF  →  FastAPI /ocr/upload  →  PyMuPDF + Tesseract (text)
             →  Gemini (text → structured JSON)  →  PostgreSQL JSONB
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter 3.x (Dart 3), Riverpod, go_router, Dio |
| Health data | Android Health Connect (`health` package) |
| On-device AI fallback | `flutter_gemma` |
| Backend | FastAPI (Python 3.10+), Uvicorn |
| Database | PostgreSQL 15+, SQLAlchemy 2 (psycopg2) |
| Authentication | Firebase Auth (Google Sign-In), email + OTP, JWT (python-jose), bcrypt |
| OCR | Tesseract 5, PyMuPDF, pdf2image, Pillow |
| AI | Google Gemini API (`google-genai`) |
| Notifications | SMTP email, Twilio SMS (optional) |

---

## 📋 Prerequisites

**Backend**
- Python 3.10+
- PostgreSQL 15+
- Tesseract OCR 5 ([install guide](https://tesseract-ocr.github.io/tessdoc/Installation.html))
- A Gemini API key ([Google AI Studio](https://aistudio.google.com/))
- [ngrok](https://ngrok.com/download) (to reach your local backend from a physical phone)

**Mobile**
- Flutter SDK 3.x and Android Studio
- A **physical Android device** (Android 8.0+, API 26+) with Health Connect installed. Health Connect does not work on emulators.

**Firebase**
- A Firebase project with Google Sign-In enabled ([Firebase Console](https://console.firebase.google.com/))

---

## 🚀 Getting Started

Set up the backend first, because the app needs the backend URL.

### 1. Clone the repository

```bash
git clone https://github.com/RayParth/Care-Predicter.git
cd Care-Predicter
```

### 2. Create the database

```bash
psql -U postgres -c "CREATE DATABASE care_predicter;"
```

Tables are created automatically the first time the backend starts (`Base.metadata.create_all`). There is no separate migration step yet.

### 3. Backend setup

```bash
cd backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install twilio                # optional: only if you want SMS OTP
```

Create `backend/.env`:

```env
# Required
SECRET_KEY=replace_with_a_long_random_string
DATABASE_URL=postgresql://username:password@localhost:5432/care_predicter

# AI
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.5-flash
GEMINI_TIMEOUT_SECONDS=60

# Email OTP (Gmail SMTP — use an app password)
SMTP_EMAIL=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# Optional SMS OTP
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=

# Optional
ENV=development                   # set to "production" to disable /docs
CORS_ORIGINS=                     # comma-separated origins, only needed for a web client
```

Generate a strong secret with:

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

**Tesseract path:** the path to the Tesseract executable is currently set in `backend/routes/ocr.py` (Windows default: `C:\Program Files\Tesseract-OCR\tesseract.exe`). Edit that line to match your system (Linux/macOS usually `/usr/bin/tesseract`).

Start the server:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- API: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs` (disabled when `ENV=production`)
- Health check: `http://localhost:8000/health`

### 4. Expose the backend with ngrok

A physical phone cannot reach `localhost`, so open a tunnel in a second terminal:

```bash
ngrok http 8000
```

Copy the `https://…ngrok-free…` forwarding URL. On the free plan it changes each time you restart ngrok.

### 5. Flutter setup

```bash
# from the project root
flutter pub get
```

Open `lib/core/constants/app_config.dart` and set `baseUrl` to your ngrok URL (or your deployed backend URL):

```dart
static const String baseUrl = 'https://your-ngrok-url.ngrok-free.app';
```

Run on a connected Android device:

```bash
flutter run
```

### 6. Firebase setup

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication → Sign-in method → Google**.
3. Add an Android app using the package name from `android/app/build.gradle`.
4. Add your SHA-1 fingerprint (needed for Google Sign-In).
5. Download `google-services.json` and place it at `android/app/google-services.json` (replace the existing file with your own project's).

---

## 🔌 API Overview

| Area | Endpoint | Purpose |
|------|----------|---------|
| Auth | `POST /auth/register`, `POST /auth/register-email` | Create an account |
| Auth | `POST /auth/login-email`, `POST /auth/google-login` | Log in and receive a JWT |
| Auth | `POST /auth/send-otp`, `POST /auth/verify-otp` | OTP verification |
| Auth | `POST /auth/forgot-password`, `POST /auth/reset-password`, `POST /auth/set-password` | Password management |
| Auth | `GET/PUT /auth/profile/{user_id}`, `GET /auth/doctors` | Profile and doctor list |
| Vitals | `POST /vitals/`, `GET /vitals/{user_id}`, `GET /vitals/{user_id}/latest` | Store and read vitals; creates alerts |
| OCR | `POST /ocr/upload` | Upload a lab report (JPG, PNG, PDF) |
| Consult | `POST /consult/`, `GET /consult/{patient_id}`, `GET /consult/doctor/{doctor_name}`, `PUT /consult/{id}/status` | Consultation requests |
| AI | `POST /ai/chat` | Gemini health assistant |
| System | `GET /health` | Health check |

Most endpoints require an `Authorization: Bearer <token>` header. See `/docs` for the full schema.

---

## 📁 Project Structure

```
Care-Predicter/
├── lib/                         # Flutter app (Dart)
│   ├── core/
│   │   ├── ai/                  # Cloud + on-device AI service
│   │   ├── constants/           # App config, API endpoints, theme tokens
│   │   ├── network/             # Dio API client
│   │   ├── providers/           # Riverpod providers
│   │   └── theme/
│   ├── features/
│   │   ├── auth/                # Login, register, OTP, role select
│   │   ├── dashboard/           # Patient home
│   │   ├── lab/                 # Lab report upload
│   │   ├── chat/                # AI assistant
│   │   ├── organ_map/           # Organ map and detail screens
│   │   ├── consult/             # Consultation requests
│   │   ├── alert/               # Alerts
│   │   └── doctor/              # Doctor dashboard, patients, alerts
│   ├── shared/                  # Services and reusable widgets
│   └── main.dart
├── backend/                     # FastAPI backend (Python)
│   ├── routes/                  # auth, vitals, ocr, consult, ai
│   ├── models.py                # SQLAlchemy models
│   ├── schemas.py               # Pydantic schemas
│   ├── security.py              # Password hashing, JWT, access checks
│   ├── config.py                # Settings from environment variables
│   ├── database.py              # Engine and session
│   ├── main.py                  # App entry point
│   └── requirements.txt
├── android/                     # Android config (Health Connect, Firebase)
├── test/                        # Flutter tests
├── pubspec.yaml
└── README.md
```

---

## 🔐 Configuration Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY` | Yes | JWT signing secret. The server will not start without it. |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `GEMINI_API_KEY` | For AI | Gemini API key (used by `/ai/chat` and OCR extraction) |
| `GEMINI_MODEL` | No | Default `gemini-2.5-flash` |
| `GEMINI_TIMEOUT_SECONDS` | No | Default `60` |
| `SMTP_EMAIL`, `SMTP_PASSWORD` | For email OTP | Gmail SMTP credentials |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER` | Optional | SMS OTP |
| `ENV` | No | `development` (default) or `production` (disables API docs) |
| `CORS_ORIGINS` | No | Comma-separated allowed origins for web clients |

Never commit your `.env` file or API keys. `.env` is listed in `.gitignore`.

---

## 🧪 Testing

Automated tests are being added. The repository currently contains only a minimal Flutter smoke test.

```bash
flutter test
```

---

## 🗺️ Roadmap

- Automated backend tests (authentication, access control, vitals validation)
- Security hardening: server-side token verification, login and OTP attempt limits, upload size limits
- Database migrations with Alembic
- Gemini accuracy test set and per-request token and cost logging
- Anomaly detection model trained on public health datasets (planned, not implemented yet)
- Docker container and cloud deployment

---

## 👥 Contributors

| Name |
|------|
| Parth Ray |
| Khushi Shah |
| Dhara Patel |
| Meet Rana |

**Supervisor:** Ms. Sapna V. Bhimajiyani, Assistant Professor
**Institution:** Parul Institute of Engineering and Technology, Parul University, Vadodara

---

## 📄 License

This project is academic software developed for the B.Tech final-year project at Parul University (2025–2026). It is not licensed for commercial use.
