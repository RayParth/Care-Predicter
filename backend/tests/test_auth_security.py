import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient

from tests.conftest import HAVE_DB

pytestmark = pytest.mark.skipif(not HAVE_DB, reason="needs embedded Postgres (pip install pgserver)")


@pytest.fixture(scope="module")
def app_client():
    import main
    return TestClient(main.app)


@pytest.fixture(autouse=True)
def strict(monkeypatch):
    from config import settings
    monkeypatch.setattr(settings, "REQUIRE_FIREBASE_TOKEN", True, raising=False)
    from routes import auth
    auth._otp_fail.clear()


def fake_claims(email):
    from firebase_auth_util import FirebaseTokenError

    def verify(token):
        # behaves like the real verifier: only the literal "tok" is a valid token
        if token != "tok":
            raise FirebaseTokenError("Missing/invalid token")
        return {"email": email, "email_verified": True}
    return verify


def register(c, monkeypatch, email, password="Passw0rd!"):
    from routes import auth
    monkeypatch.setattr(auth, "verify_firebase_id_token", fake_claims(email))
    r = c.post("/auth/register", json={"email": email, "name": "T", "role": "patient",
                                       "password": password, "id_token": "tok"})
    assert r.status_code == 200, r.text
    return r.json()


def test_google_login_with_only_an_email_is_rejected(app_client, monkeypatch):
    register(app_client, monkeypatch, "victim1@example.com")
    r = app_client.post("/auth/google-login", json={"email": "victim1@example.com", "name": "x", "role": ""})
    assert r.status_code == 401
    assert "access_token" not in r.text


def test_google_login_with_valid_token_works(app_client, monkeypatch):
    register(app_client, monkeypatch, "ok1@example.com")
    r = app_client.post("/auth/google-login", json={"email": "ok1@example.com", "name": "x", "role": "", "id_token": "tok"})
    assert r.status_code == 200 and r.json()["access_token"]


def test_token_for_a_different_email_is_rejected(app_client, monkeypatch):
    register(app_client, monkeypatch, "victim2@example.com")
    from routes import auth
    monkeypatch.setattr(auth, "verify_firebase_id_token", fake_claims("attacker@example.com"))
    r = app_client.post("/auth/google-login", json={"email": "victim2@example.com", "name": "x", "role": "", "id_token": "tok"})
    assert r.status_code == 401


def test_register_cannot_overwrite_existing_account_without_token(app_client, monkeypatch):
    register(app_client, monkeypatch, "victim3@example.com", password="OriginalPass1")
    r = app_client.post("/auth/register", json={"email": "victim3@example.com", "name": "pwn", "role": "patient", "password": "hacked123"})
    assert r.status_code == 401
    ok = app_client.post("/auth/login-email", json={"email": "victim3@example.com", "password": "OriginalPass1"})
    assert ok.status_code == 200


def test_set_password_requires_login_and_ownership(app_client, monkeypatch):
    victim = register(app_client, monkeypatch, "victim4@example.com")
    attacker = register(app_client, monkeypatch, "attacker4@example.com")
    body = {"email": "victim4@example.com", "password": "hacked123"}
    assert app_client.post("/auth/set-password", json=body).status_code in (401, 403)
    h = {"Authorization": f"Bearer {attacker['access_token']}"}
    assert app_client.post("/auth/set-password", json=body, headers=h).status_code == 403
    h2 = {"Authorization": f"Bearer {victim['access_token']}"}
    assert app_client.post("/auth/set-password", json={"email": "victim4@example.com", "password": "newpass123"}, headers=h2).status_code == 200


def test_otp_brute_force_is_stopped(app_client, monkeypatch):
    register(app_client, monkeypatch, "otp5@example.com")
    from database import SessionLocal
    from models import OtpCode
    db = SessionLocal()
    db.add(OtpCode(email="otp5@example.com", code="123456", used=False,
                   expires_at=datetime.utcnow() + timedelta(minutes=10)))
    db.commit(); db.close()
    for guess in ("000001", "000002", "000003", "000004", "000005"):
        assert app_client.post("/auth/verify-otp", json={"email": "otp5@example.com", "code": guess}).status_code == 400
    # 6th attempt is blocked even though it is the CORRECT code
    r = app_client.post("/auth/verify-otp", json={"email": "otp5@example.com", "code": "123456"})
    assert r.status_code == 429


def test_dev_mode_flag_off_allows_old_behaviour(app_client, monkeypatch):
    from config import settings
    monkeypatch.setattr(settings, "REQUIRE_FIREBASE_TOKEN", False, raising=False)
    r = app_client.post("/auth/google-login", json={"email": "newuser@example.com", "name": "n", "role": ""})
    assert r.status_code == 200 and r.json()["needs_registration"] is True
