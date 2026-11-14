ALTER TABLE system_events
    ADD COLUMN result varchar(10) NOT NULL DEFAULT 'SUCCESS'
        CHECK (result IN ('SUCCESS', 'FAILED')),
    ADD COLUMN description text NOT NULL DEFAULT '';

CREATE INDEX events_result_date_idx ON system_events(result, occurred_at DESC);
