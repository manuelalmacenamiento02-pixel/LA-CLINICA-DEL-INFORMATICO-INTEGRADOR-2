ALTER TABLE technical_attentions
    ADD COLUMN IF NOT EXISTS performed_tests text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS parts_used text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS observations text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS result_summary text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES users(id);

UPDATE technical_attentions
SET updated_by = technician_id
WHERE updated_by IS NULL;

ALTER TABLE service_orders
    ADD COLUMN IF NOT EXISTS finalized_at timestamptz,
    ADD COLUMN IF NOT EXISTS finalized_by uuid REFERENCES users(id);

UPDATE service_orders
SET finalized_at = COALESCE(closed_at, updated_at, created_at),
    finalized_by = received_by
WHERE status_code = 'FINALIZADA'
  AND (finalized_at IS NULL OR finalized_by IS NULL);

ALTER TABLE service_orders
    ADD CONSTRAINT service_orders_finalized_metadata
    CHECK (
        (status_code = 'FINALIZADA' AND finalized_at IS NOT NULL AND finalized_by IS NOT NULL)
        OR (status_code <> 'FINALIZADA' AND finalized_at IS NULL AND finalized_by IS NULL)
    );

ALTER TABLE ai_prediagnoses
    ADD COLUMN IF NOT EXISTS result_data jsonb;

ALTER TABLE ai_validations
    ALTER COLUMN final_diagnosis DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS modified_data jsonb;

ALTER TABLE ai_validations
    DROP CONSTRAINT IF EXISTS ai_validations_decision_check;

ALTER TABLE ai_validations
    ADD CONSTRAINT ai_validations_decision_check
    CHECK (decision IN ('ACEPTADO','MODIFICADO','DESCARTADO','RECHAZADO'));
