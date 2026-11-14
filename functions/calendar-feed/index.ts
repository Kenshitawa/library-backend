// Supabase Edge Function: calendar-feed
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function formatIcsDate(isoString: string): string {
  const date = new Date(isoString)
  return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z'
}

serve(async (req) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').pop()?.replace('.ics', '')

  if (!token) {
    return new Response('Missing feed token', { status: 400 })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Verify token
    const { data: feed, error: feedError } = await supabaseAdmin
      .from('calendar_feeds')
      .select('*')
      .eq('token_hash', token)
      .is('revoked_at', null)
      .single()

    if (feedError || !feed) {
      return new Response('Calendar feed token is invalid or has been revoked.', {
        status: 404,
        headers: { 'Content-Type': 'text/plain' },
      })
    }

    // Fetch open issues
    const { data: issues, error: issuesError } = await supabaseAdmin
      .from('issues')
      .select(`
        id,
        issued_at,
        due_at,
        copy:copies(barcode, title:titles(title, author)),
        borrower:borrowers(name, borrower_no)
      `)
      .eq('status', 'open')

    if (issuesError) throw issuesError

    // Construct iCalendar (RFC 5545) VCALENDAR string
    const events = (issues || []).map((issue: any) => {
      const summary = `${issue.borrower?.name} - ${issue.copy?.title?.title || 'Book Return'}`
      const description = `Title: ${issue.copy?.title?.title}\\nBorrower: ${issue.borrower?.name} (${issue.borrower?.borrower_no})\\nCopy Barcode: ${issue.copy?.barcode}`
      const dtStart = formatIcsDate(issue.issued_at)
      const dtEnd = formatIcsDate(issue.due_at)
      const dtStamp = formatIcsDate(new Date().toISOString())

      return [
        'BEGIN:VEVENT',
        `UID:${issue.id}@school-library.local`,
        `DTSTAMP:${dtStamp}`,
        `DTSTART:${dtStart}`,
        `DTEND:${dtEnd}`,
        `SUMMARY:${summary}`,
        `DESCRIPTION:${description}`,
        'BEGIN:VALARM',
        'TRIGGER:-P3D',
        'ACTION:DISPLAY',
        'DESCRIPTION:Textbook return due in 3 days',
        'END:VALARM',
        'END:VEVENT',
      ].join('\r\n')
    })

    const icsContent = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//School Library//Due Dates Calendar 1.0//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:School Library Returns',
      'X-WR-TIMEZONE:Africa/Nairobi',
      ...events,
      'END:VCALENDAR',
    ].join('\r\n')

    return new Response(icsContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/calendar; charset=utf-8',
        'Content-Disposition': 'inline; filename="library-due-dates.ics"',
        'Cache-Control': 'no-cache, no-store, max-age=0, must-revalidate',
      },
    })
  } catch (err: any) {
    return new Response(`Server error: ${err.message}`, { status: 500 })
  }
})
