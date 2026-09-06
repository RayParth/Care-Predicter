# Care AI setup

This project now uses a cloud-first, offline-fallback AI architecture.

## Online AI

Flutter calls:

`POST /ai/chat`

through the existing authenticated `ApiClient`.

The FastAPI backend calls OpenAI's Responses API. The OpenAI key is never stored in Flutter.

Create `backend/.env` from `.env.example` and set:

```env
SECRET_KEY=your-existing-secret
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-5.6-luna
OPENAI_TIMEOUT_SECONDS=60
```

Then install the backend requirements:

```powershell
cd backend
python -m pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Use the same `AppConfig.baseUrl`/ngrok setup already used by the project.

## Offline Gemma 4

The Flutter app uses `flutter_gemma: ^0.16.5` and Gemma 4 E2B in LiteRT-LM format.

The model is intentionally NOT bundled into the APK. It is several GB and should be explicitly installed by the user.

Open the AI chat screen, tap the three-dot menu, and choose:

`Install offline Gemma 4`

The model URL is:

`https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`

After installation, messages automatically fall back to Gemma when the backend/OpenAI request fails.

## Important Android limitation

The LiteRT-LM Gemma path requires ARM64 Android for full on-device inference. An x86_64 emulator should be used for UI/cloud testing only.

A compatible physical ARM64 phone with sufficient RAM and several GB of free storage is recommended.

## Runtime behavior

```text
Flutter chat
    |
    +-- backend reachable --> FastAPI --> OpenAI
    |
    +-- backend fails ------> local Gemma 4 E2B
```

Health Connect data remains on the device until the user sends a chat message. For online requests, the relevant health context is sent to the authenticated backend. The backend also merges the user's own stored lab/vital data using the authenticated user ID.

The local Gemma path receives the same health context directly on-device.
