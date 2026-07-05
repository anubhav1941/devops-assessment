CREATE INDEX IF NOT EXISTS idx_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
