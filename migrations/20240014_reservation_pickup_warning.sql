DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'expire-reservations';

    PERFORM cron.schedule('expire-reservations', '0 * * * *', $cron$
      WITH expired_res AS (
        UPDATE public.reservations
        SET status = 'expired', updated_at = now()
        WHERE status = 'ready'
          AND pickup_deadline < now()
          AND deleted_at IS NULL
        RETURNING id, borrower_id, title_id, ready_copy_id, pickup_deadline
      ),
      warning_letters AS (
        INSERT INTO public.notifications (
          borrower_id, type, channel, subject, body, status, sent_at
        )
        SELECT
          expired.borrower_id,
          'reservation_pickup_warning',
          'in_app',
          'Book reservation not collected',
          format(
            E'Dear %s,\n\nOur records show that the reserved book "%s" was not collected by the pickup deadline of %s. The reservation has now expired. Please contact the library if you still need this book.\n\nSincerely,\n%s',
            borrower.name,
            title.title,
            to_char(COALESCE(expired.pickup_deadline, now()), 'DD Mon YYYY HH24:MI'),
            COALESCE((SELECT name FROM public.library_profile ORDER BY created_at LIMIT 1), 'School Library')
          ),
          'sent',
          now()
        FROM expired_res expired
        JOIN public.borrowers borrower ON borrower.id = expired.borrower_id
        JOIN public.titles title ON title.id = expired.title_id
        RETURNING id
      )
      SELECT public.handle_return_reservations(expired.ready_copy_id)
      FROM expired_res expired
      WHERE expired.ready_copy_id IS NOT NULL;

      UPDATE public.copies copy
      SET status = 'available', updated_at = now()
      WHERE copy.status = 'reserved'
        AND NOT EXISTS (
          SELECT 1
          FROM public.reservations reservation
          WHERE reservation.ready_copy_id = copy.id
            AND reservation.status = 'ready'
        );
    $cron$);
  END IF;
END $$;
