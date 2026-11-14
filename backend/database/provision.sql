-- Run with psql as a database administrator. Secrets come from environment variables.
\set ON_ERROR_STOP on
\getenv app_password CLINICA_APP_PASSWORD
SELECT format('CREATE ROLE clinica_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'app_password')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='clinica_app')
\gexec
SELECT 'CREATE DATABASE clinica_informatica OWNER clinica_app ENCODING ''UTF8'''
 WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='clinica_informatica')
\gexec
-- Existing databases, roles and passwords are preserved.
