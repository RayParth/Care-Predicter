"""Small helpers shared by routes/ai.py and routes/ocr.py."""
from config import settings


def models_to_try() -> list[str]:
    seen, out = set(), []
    for m in [settings.GEMINI_MODEL, *settings.GEMINI_FALLBACK_MODELS]:
        if m and m not in seen:
            seen.add(m)
            out.append(m)
    return out


def is_model_gone(exc: Exception) -> bool:
    """True when the error means 'this model id was retired / doesn't exist'."""
    msg = str(exc).lower()
    return "404" in msg or "not_found" in msg or "no longer available" in msg
