# 🩺 Care-Predicter — AI-Driven Health Monitoring System

> **Flutter + FastAPI · Android · PostgreSQL · Health Connect · OCR · ML**

A mobile health monitoring platform that collects real wearable data via Android Health Connect, extracts lab values from uploaded reports using Tesseract OCR, and runs LSTM / Random Forest / SVM anomaly detection on a FastAPI backend — all presented through a clean Flutter UI with role-based access for patients and doctors.

---

## 📱 Screenshots

| Login | Patient Dashboard | Organ Map | Doctor Dashboard |
|-------|------------------|-----------|-----------------|
| Firebase Gmail auth | Live vitals + health score | Tap organ → view data | AI patient summaries |

> Full screenshots available in `/docs/screenshots/` or in the project report.

---

## ✨ Features

- **Real-time Health Dashboard** — heart rate, SpO2, steps, sleep, calories, temperature synced every 10 minutes from Android Health Connect
- **OCR Lab Report Extraction** — upload a photo or PDF of a blood test; Tesseract v5 extracts glucose, cholesterol, hemoglobin, WBC, and more automatically
- **AI Anomaly Detection** — LSTM + Random Forest + SVM ensemble (F1: 94.2%) detects health deterioration patterns in real time
- **Composite Health Score** — weighted 0–100 index across all parameters with Excellent / Good / Caution / Critical bands
- **Dynamic Organ Health Map** — tappable body diagram; each organ shows relevant health readings and an AI tip
- **AI Chat Assistant** — ask natural language questions about your own health data; answers are grounded in your actual readings
- **Emergency Alerts** — in-app + SMS notifications; rule-based fallback keeps alerts running if the ML service is down
- **Doctor Consultation Module** — AI-generated patient summaries for doctors before each remote consultation
- **Offline-first** — data queues in local SQLite when internet is unavailable and syncs automatically on reconnect
- **Role-based Access** — separate interfaces for Patient, Doctor, and Admin roles via Firebase Auth

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│   Presentation Tier — Flutter (Android)      │
│  Login · Dashboard · Organ Map · AI Chat     │
└────────────────┬────────────────────────────┘
                 │ REST API + JWT (Dio)
┌────────────────▼────────────────────────────┐
│   Application Logic — FastAPI (Uvicorn)      │
│  Auth · Health API · OCR Service · ML Engine │
└────────────────┬────────────────────────────┘
                 │ SQLAlchemy ORM
┌────────────────▼────────────────────────────┐
│   Data Tier — PostgreSQL v15                 │
│  users · wearable_data · lab_results ·       │
│  health_scores · alerts                      │
└─────────────────────────────────────────────┘

External: Health Connect API · Firebase Auth · Tesseract OCR
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile frontend | Flutter v3.x (Dart 3) |
| State management | flutter_riverpod |
| HTTP client | Dio |
| Backend | FastAPI (Python 3.10+) on Uvicorn |
| Database | PostgreSQL v15 |
| ORM | SQLAlchemy v2 |
| Authentication | Firebase Auth (Gmail) + JWT |
| Health data | Android Health Connect API (SDK 34+) |
| OCR | Tesseract OCR v5 + pdf2image |
| ML models | TensorFlow/Keras (LSTM) + Scikit-learn (RF, SVM) |
| Offline storage | SharedPreferences + local SQLite queue |

---

## 📋 Prerequisites

Install these before starting — in this order:

**Backend first:**
- Python 3.10+ — [download](https://www.python.org/downloads/)
- PostgreSQL 15 — [download](https://www.postgresql.org/download/)
- Tesseract OCR v5 — [install guide](https://tesseract-ocr.github.io/tessdoc/Installation.html)
- [ngrok](https://ngrok.com/download) — exposes your local backend to the Android device

**Then Flutter:**
- Flutter SDK v3.x — [install guide](https://docs.flutter.dev/get-started/install)
- Dart SDK v3.x (bundled with Flutter)
- Android Studio Hedgehog or later — [download](https://developer.android.com/studio)
- A physical Android device running Android 8.0+ (API 26+) with Health Connect installed

**Then Firebase:**
- A Firebase project with Google Sign-In enabled — [Firebase Console](https://console.firebase.google.com/)

---

## 🚀 Getting Started

Follow these steps **in order** — the Flutter app depends on the backend URL, so get the backend running first.

### 1. Clone the repo

```bash
git clone https://github.com/RayParth/Care-Predicter.git
cd Care-Predicter
```

---

### 2. Backend Setup

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

Create a `.env` file in the `backend/` folder:

```env
DATABASE_URL=postgresql://username:password@localhost:5432/care_predicter
SECRET_KEY=your_jwt_secret_key_here
FIREBASE_PROJECT_ID=your_firebase_project_id
TESSERACT_CMD=/usr/bin/tesseract   # Windows example: C:/Program Files/Tesseract-OCR/tesseract.exe
```

Start the backend server:

```bash
uvicorn main:app --reload
```

Local API: `http://localhost:8000`
Swagger docs: `http://localhost:8000/docs`

---

### 3. PostgreSQL Database Setup

```bash
# Create the database
psql -U postgres -c "CREATE DATABASE care_predicter;"

# Run migrations
alembic upgrade head
```

> Make sure `DATABASE_URL` in your `.env` matches your local PostgreSQL credentials.

---

### 4. Expose Backend via ngrok

Since the Flutter app runs on a **physical Android device**, it cannot reach `localhost` directly. Use ngrok to create a public tunnel to your local backend.

```bash
# In a new terminal (keep uvicorn running in the other)
ngrok http 8000
```

ngrok will print a forwarding URL like:

```
Forwarding   https://a1b2-103-xyz.ngrok-free.app -> http://localhost:8000
```

**Copy that `https://` URL** — you'll need it in the next step.

> ⚠️ ngrok URLs change every time you restart ngrok (on the free plan). You'll need to update the Flutter config each session, or upgrade to a paid ngrok plan for a static domain.

---

### 5. Flutter App Setup

```bash
# From the project root
flutter pub get
```

Open `lib/core/constants/api_constants.dart` (or equivalent config file) and paste your ngrok URL:

```dart
const String baseUrl = 'https://a1b2-103-xyz.ngrok-free.app';
// Replace with your actual ngrok URL each session
```

Run the app on your connected Android device:

```bash
flutter run
```

> **Note:** Health Connect requires a **physical Android device** running Android 8.0+ (API 26+) with the Health Connect app installed. It does not work on emulators.

---

### 6. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a project
2. Enable **Authentication → Sign-in method → Google**
3. Add an Android app — use the package name from `android/app/build.gradle` (e.g. `com.example.care_predicter`)
4. Download `google-services.json` and place it at `android/app/google-services.json`
5. Add your `FIREBASE_PROJECT_ID` to the backend `.env` file

---

## 📁 Project Structure

```
Care-Predicter/
├── lib/                        # Flutter app (Dart)
│   ├── core/                   # Constants, themes, utilities
│   ├── features/               # Feature modules (auth, dashboard, ocr, etc.)
│   └── main.dart               # App entry point
├── backend/                    # FastAPI backend (Python)
│   ├── routes/                 # API route handlers
│   ├── models/                 # SQLAlchemy DB models
│   ├── services/               # Business logic (OCR, ML, alerts)
│   ├── ml/                     # Trained ML model files
│   ├── main.py                 # FastAPI app entry point
│   └── requirements.txt        # Python dependencies
├── android/                    # Android-specific Flutter config
├── ios/                        # iOS-specific Flutter config
├── test/                       # Flutter unit and widget tests
├── pubspec.yaml                # Flutter dependencies
└── README.md
```

---

## 🤖 ML Models

Models are trained on the MIT-BIH Arrhythmia Database, PhysioNet MIMIC-III (subset), and UCI Heart Disease dataset (~180,000 labeled records).

| Model | Accuracy | F1-Score |
|-------|----------|----------|
| Random Forest | 91.3% | 89.0% |
| SVM (RBF Kernel) | 88.6% | 87.0% |
| LSTM | 94.2% | 92.9% |
| **Ensemble (RF + LSTM)** | **95.8%** | **94.2%** |

To retrain models, open the notebooks in `backend/ml/notebooks/` in Google Colab and follow the instructions there.

---

## 🔌 Key Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY` | JWT signing secret |
| `FIREBASE_PROJECT_ID` | Firebase project ID for token verification |
| `TESSERACT_CMD` | Path to Tesseract binary on your system |

---

## 🧪 Running Tests

**Flutter:**
```bash
flutter test
```

**Backend:**
```bash
cd backend
pytest
```

---

## 👥 Contributors

| Name | Roll No. |
|------|----------|
| Parth Ray | 2403031087129 | 
| Khushi Shah | 2403031087157 | 
| Dhara Patel | 2303031080223 | 
| Meet Rana | 2403031087086 |

**Supervisor:** Ms. Sapna V. Bhimajiyani, Assistant Professor
**Institution:** Parul Institute of Engineering and Technology, Parul University, Vadodara

---

## 📄 License

This project is academic software developed for the B.Tech final year project at Parul University (2025–2026). Not licensed for commercial use.
