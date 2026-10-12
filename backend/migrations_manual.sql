-- Run ONLY against a database that already exists (e.g. your local one).
-- A brand-new database (fresh Railway Postgres) does not need this:
-- the app creates every table on first start.
-- SQLAlchemy create_all() never ALTERs existing tables, so new columns must be added by hand.

-- from feature/ocr-dynamic-medical-report-extraction
ALTER TABLE lab_reports ADD COLUMN IF NOT EXISTS extracted_data JSONB NOT NULL DEFAULT '{}'::jsonb;

-- from feature/offline-sync (idempotent vitals upload)
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);
CREATE UNIQUE INDEX IF NOT EXISTS uq_vitals_user_client ON vitals (user_id, client_id);
