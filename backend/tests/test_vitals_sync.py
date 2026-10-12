import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from tests.conftest import HAVE_DB

pytestmark = pytest.mark.skipif(not HAVE_DB, reason="needs embedded Postgres")


@pytest.fixture(scope="module")
def ctx():
    import main
    from config import settings
    settings.REQUIRE_FIREBASE_TOKEN = False
    c = TestClient(main.app)
    u = c.post("/auth/register", json={"email": "sync@example.com", "name": "S", "role": "patient", "password": "Passw0rd!"}).json()
    return c, {"Authorization": f"Bearer {u['access_token']}"}, u["id"]


def reading(uid, **kw):
    base = dict(user_id=uid, heart_rate=76, spo2=98, steps=6000, calories=1800, sleep_hours=7, temperature=0.0)
    base.update(kw)
    return base


def test_missing_temperature_is_accepted(ctx):
    c, h, uid = ctx
    # This exact payload used to be rejected with 422, silently losing the reading.
    assert c.post("/vitals/", json=reading(uid), headers=h).status_code == 200


def test_implausible_temperature_still_rejected(ctx):
    c, h, uid = ctx
    assert c.post("/vitals/", json=reading(uid, temperature=5.0), headers=h).status_code == 422
    assert c.post("/vitals/", json=reading(uid, temperature=50.0), headers=h).status_code == 422


def test_batch_is_idempotent_and_keeps_measurement_time(ctx):
    c, h, uid = ctx
    t = (datetime.utcnow() - timedelta(hours=5)).replace(microsecond=0)
    items = [reading(uid, client_id="aaa-1", recorded_at=t.isoformat(), steps=111),
             reading(uid, client_id="aaa-2", recorded_at=(t + timedelta(minutes=10)).isoformat(), steps=222)]
    r1 = c.post("/vitals/batch", json={"items": items}, headers=h).json()
    assert r1["accepted"] == ["aaa-1", "aaa-2"] and not r1["duplicates"]
    r2 = c.post("/vitals/batch", json={"items": items}, headers=h).json()      # retry after a timeout
    assert r2["accepted"] == [] and r2["duplicates"] == ["aaa-1", "aaa-2"]
    rows = c.get(f"/vitals/{uid}", headers=h).json()
    old = [x for x in rows if x["steps"] in (111, 222)]
    assert len(old) == 2                                   # no duplicates
    assert any(x["recorded_at"].startswith(t.isoformat()[:16]) for x in old)   # original time kept


def test_old_critical_reading_does_not_raise_new_alert(ctx):
    c, h, uid = ctx
    from database import SessionLocal
    from models import Alert
    db = SessionLocal()
    before = db.query(Alert).filter(Alert.user_id == uid).count()
    old = (datetime.utcnow() - timedelta(hours=6)).isoformat()
    c.post("/vitals/batch", json={"items": [reading(uid, client_id="old-crit", spo2=85, recorded_at=old)]}, headers=h)
    after_old = db.query(Alert).filter(Alert.user_id == uid).count()
    assert after_old == before                              # stale reading: no alert
    c.post("/vitals/batch", json={"items": [reading(uid, client_id="new-crit", spo2=85)]}, headers=h)
    db.expire_all()
    assert db.query(Alert).filter(Alert.user_id == uid).count() > after_old   # fresh one does
    db.close()


def test_future_timestamp_rejected(ctx):
    c, h, uid = ctx
    fut = (datetime.utcnow() + timedelta(days=2)).isoformat()
    r = c.post("/vitals/batch", json={"items": [reading(uid, client_id="fut", recorded_at=fut)]}, headers=h).json()
    assert r["rejected"] and r["rejected"][0]["client_id"] == "fut"


def test_cannot_batch_for_someone_else(ctx):
    c, h, uid = ctx
    assert c.post("/vitals/batch", json={"items": [reading(uid + 999, client_id="x")]}, headers=h).status_code == 403
