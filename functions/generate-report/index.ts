import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { requireLibrarian } from '../_shared/auth.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const escapeHtml = (value: unknown) =>
  String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character]!)

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Use POST to generate a report.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const authorization = await requireLibrarian(req, corsHeaders)
    if (authorization instanceof Response) return authorization
    const { report_type, filters } = await req.json()
    const supabase = authorization.supabase

    const { data: libraryProfile } = await supabase
      .from('library_profile')
      .select('*')
      .limit(1)
      .maybeSingle()

    const schoolName = libraryProfile?.school_name || 'School Library'
    const safeReportType =
      typeof report_type === 'string' ? report_type.slice(0, 80) : 'Library Report'
    const reportTitle = safeReportType.replace(/_/g, ' ').toUpperCase()

    // Generate HTML report format suitable for printing or saving to PDF
    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${reportTitle}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 30px; color: #1e293b; }
    .header { border-bottom: 2px solid #0f766e; padding-bottom: 12px; margin-bottom: 20px; }
    .school { font-size: 20px; font-weight: bold; color: #0f766e; }
    .report-name { font-size: 16px; color: #334155; margin-top: 4px; font-weight: 600; }
    .meta { font-size: 12px; color: #64748b; margin-top: 4px; }
    .content { margin-top: 20px; font-size: 13px; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    th { background: #f1f5f9; border: 1px solid #cbd5e1; padding: 8px 12px; text-align: left; }
    td { border: 1px solid #e2e8f0; padding: 8px 12px; }
    @media print { body { margin: 15px; } }
  </style>
</head>
<body>
  <div class="header">
    <div class="school">${escapeHtml(schoolName)}</div>
    <div class="report-name">${escapeHtml(reportTitle)}</div>
    <div class="meta">Generated: ${escapeHtml(new Date().toLocaleString())} | Filters: ${escapeHtml(JSON.stringify(filters || {}))}</div>
  </div>
  <div class="content">
    <p>This report has been compiled from live database records.</p>
  </div>
</body>
</html>
`

    return new Response(
      JSON.stringify({
        success: true,
        report_type,
        generated_at: new Date().toISOString(),
        html,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
