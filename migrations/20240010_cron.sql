-- Migration: 20240010_cron.sql
-- Pickup expiry pg_cron job
-- Note: When pg_cron extension is enabled on the cloud Supabase project:

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule('expire-reservations', '0 * * * *', $cron$
      -- 1. Expire reservations where pickup_deadline has passed
      WITH expired_res AS (
        UPDATE public.reservations
        SET status = 'expired', updated_at = now()
        WHERE status = 'ready' AND pickup_deadline < now()
        RETURNING id, title_id, ready_copy_id
      )
      -- 2. For each freed copy, invoke return reservations logic
      SELECT public.handle_return_reservations(ready_copy_id)
      FROM expired_res
      WHERE ready_copy_id IS NOT NULL;

      -- 3. For any copy that had an expired reservation and was not reassigned, reset status to available
      UPDATE public.copies c
      SET status = 'available', updated_at = now()
      WHERE status = 'reserved'
        AND NOT EXISTS (
          SELECT 1 FROM public.reservations r
          WHERE r.ready_copy_id = c.id AND r.status = 'ready'
        );
    $cron$);
  END IF;
END $$;
