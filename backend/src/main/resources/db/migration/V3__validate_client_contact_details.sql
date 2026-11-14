ALTER TABLE clients DROP CONSTRAINT IF EXISTS clients_phone_check;
ALTER TABLE clients ADD CONSTRAINT clients_phone_nine_digits
 CHECK (phone ~ '^[0-9]{9}$') NOT VALID;

ALTER TABLE clients ADD CONSTRAINT clients_email_required_and_valid
 CHECK (email = btrim(email)
   AND email <> ''
   AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') NOT VALID;

CREATE UNIQUE INDEX clients_email_unique ON clients (lower(btrim(email)))
 WHERE btrim(email) <> '';
