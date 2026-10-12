"""Verify the Firebase ID token the Flutter app obtains after Google sign-in.

Without this, anyone who knows an email address can call /auth/google-login
and receive a valid JWT for that account.
"""
from google.auth.transport import requests as g_requests
from google.oauth2 import id_token as g_id_token

from config import settings

_request = g_requests.Request()


class FirebaseTokenError(Exception):
    pass


def verify_firebase_id_token(token: str) -> dict:
    if not settings.FIREBASE_PROJECT_ID:
        raise FirebaseTokenError("FIREBASE_PROJECT_ID is not configured on the server")
    if not token:
        raise FirebaseTokenError("Missing Firebase ID token")
    try:
        claims = g_id_token.verify_firebase_token(
            token, _request, audience=settings.FIREBASE_PROJECT_ID
        )
    except Exception as exc:  # noqa: BLE001  (bad signature, expired, wrong audience...)
        raise FirebaseTokenError(f"Invalid Firebase token: {exc}") from exc
    if not claims:
        raise FirebaseTokenError("Invalid Firebase token")
    if claims.get("iss") != f"https://securetoken.google.com/{settings.FIREBASE_PROJECT_ID}":
        raise FirebaseTokenError("Token issuer mismatch")
    if not claims.get("email"):
        raise FirebaseTokenError("Token has no email")
    if claims.get("email_verified") is False:
        raise FirebaseTokenError("Google account email is not verified")
    return claims
