-- 10_roles.sql — cluster-wide group roles for the CTD team's `calcofi` database.
-- Idempotent; run as superuser against any database:
--   docker exec -i postgis psql -U admin -d postgres -f /share/github/CalCOFI/server/postgis/init/10_roles.sql
--
--   calcofi_reader    SELECT everywhere in `calcofi`                       (apps, pipeline, everyone)
--   calcofi_writer    reader + INSERT/UPDATE/DELETE in `work`, own schema, ctd.flag
--   calcofi_curator   writer + may accept/reject flags (ctd.flag.status)
--   calcofi_loader    INSERT into the immutable ctd.file / ctd.scan (loader notebook only)
--   calcofi_admin     owns the schemas; curator + loader; CREATEROLE for add_user.sh
--   calcofi_pipeline  LOGIN service role (reader) for workflows; password set by hand
--   calcofi_app       LOGIN service role (reader) for the ctd-qaqc app; password set by hand
-- Login roles for people are created by scripts/add_user.sh (one per person, IN ROLE these).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_reader')   THEN CREATE ROLE calcofi_reader   NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_writer')   THEN CREATE ROLE calcofi_writer   NOLOGIN IN ROLE calcofi_reader; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_curator')  THEN CREATE ROLE calcofi_curator  NOLOGIN IN ROLE calcofi_writer; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_loader')   THEN CREATE ROLE calcofi_loader   NOLOGIN IN ROLE calcofi_reader; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_admin')    THEN CREATE ROLE calcofi_admin    NOLOGIN CREATEROLE IN ROLE calcofi_curator, calcofi_loader; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_pipeline') THEN CREATE ROLE calcofi_pipeline LOGIN IN ROLE calcofi_reader; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'calcofi_app')      THEN CREATE ROLE calcofi_app      LOGIN IN ROLE calcofi_reader; END IF;
END $$;
