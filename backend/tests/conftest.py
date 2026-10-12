import os
import sys
import tempfile
import warnings

warnings.filterwarnings("ignore")

# Must be set before importing config/database.
os.environ.setdefault("SECRET_KEY", "x" * 40)
os.environ.setdefault("GEMINI_API_KEY", "test-key")
os.environ.setdefault("FIREBASE_PROJECT_ID", "carepredicter")

# Use a throwaway embedded Postgres when available (pip install pgserver);
# otherwise a dummy URL is enough for the tests that never touch the DB.
try:
    import pgserver
    _srv = pgserver.get_server(tempfile.mkdtemp())
    os.environ["DATABASE_URL"] = _srv.get_uri()
    HAVE_DB = True
except Exception:  # pragma: no cover
    os.environ.setdefault("DATABASE_URL", "postgresql://u:p@localhost:5432/test")
    HAVE_DB = False

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
