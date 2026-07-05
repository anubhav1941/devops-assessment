
BEGIN;

CREATE TEMP TABLE tmp_orgs AS
SELECT gen_random_uuid() AS org_id FROM generate_series(1, 8);

CREATE TEMP TABLE tmp_cities (city TEXT);
INSERT INTO tmp_cities (city) VALUES
    ('delhi'), ('mumbai'), ('bangalore'), ('chennai'), ('kolkata'), ('pune');

CREATE TEMP TABLE tmp_statuses (status TEXT);
INSERT INTO tmp_statuses (status) VALUES
    ('confirmed'), ('cancelled'), ('pending'), ('completed'), ('refunded');

DO $$
DECLARE
    i               INT;
    v_org_id        UUID;
    v_city          TEXT;
    v_status        TEXT;
    v_checkin       DATE;
    v_checkout      DATE;
    v_amount        NUMERIC(12,2);
    v_created_at    TIMESTAMP;
    v_booking_id    UUID;
    v_num_orgs      INT;
    v_num_cities    INT;
    v_num_statuses  INT;
BEGIN
    SELECT COUNT(*) INTO v_num_orgs FROM tmp_orgs;
    SELECT COUNT(*) INTO v_num_cities FROM tmp_cities;
    SELECT COUNT(*) INTO v_num_statuses FROM tmp_statuses;

    FOR i IN 1..5000 LOOP
        SELECT org_id INTO v_org_id FROM tmp_orgs OFFSET floor(random() * v_num_orgs) LIMIT 1;
        SELECT city INTO v_city FROM tmp_cities OFFSET floor(random() * v_num_cities) LIMIT 1;
        SELECT status INTO v_status FROM tmp_statuses OFFSET floor(random() * v_num_statuses) LIMIT 1;

        IF random() < 0.35 THEN
            v_created_at := NOW() - (random() * INTERVAL '30 days');
        ELSE
            v_created_at := NOW() - (INTERVAL '30 days' + random() * INTERVAL '150 days');
        END IF;

        v_checkin  := (v_created_at + (random() * INTERVAL '60 days'))::DATE;
        v_checkout := v_checkin + (1 + floor(random() * 6))::INT;
        v_amount   := round((2000 + random() * 48000)::NUMERIC, 2);

        INSERT INTO hotel_bookings
            (org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
        VALUES
            (v_org_id, 'HTL-' || lpad((1 + floor(random() * 40))::TEXT, 4, '0'),
             v_city, v_checkin, v_checkout, v_amount, v_status, v_created_at)
        RETURNING id INTO v_booking_id;

        IF random() < 0.5 THEN
            INSERT INTO booking_events (booking_id, event_type, payload, created_at)
            VALUES (
                v_booking_id,
                (ARRAY['created','payment_received','confirmed','cancelled','checked_in','checked_out'])[1 + floor(random()*6)],
                jsonb_build_object('source', 'seed_script', 'note', 'auto-generated event'),
                v_created_at + (random() * INTERVAL '2 days')
            );
        END IF;
    END LOOP;
END $$;

COMMIT;

SELECT COUNT(*) AS total_bookings FROM hotel_bookings;
SELECT city, COUNT(*) FROM hotel_bookings GROUP BY city ORDER BY city;
SELECT COUNT(*) AS total_events FROM booking_events;
