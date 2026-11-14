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
      return new Response(JSON.stringify({ error: 'Use POST to generate a receipt.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const authorization = await requireLibrarian(req, corsHeaders)
    if (authorization instanceof Response) return authorization
    const supabase = authorization.supabase
    const { payment_id } = await req.json()
    if (typeof payment_id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(payment_id)) {
      return new Response(JSON.stringify({ error: 'Missing payment_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Fetch payment, borrower, charge, and library profile
    const { data: payment, error: pErr } = await supabase
      .from('payments')
      .select(`
        *,
        borrower:borrowers(*),
        charge:charges(
          *,
          issue:issues(
            *,
            copy:copies(*, title:titles(*))
          )
        ),
        receiver:users_profile(name, email)
      `)
      .eq('id', payment_id)
      .single()

    if (pErr || !payment) {
      return new Response(JSON.stringify({ error: 'Payment not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: libraryProfile } = await supabase
      .from('library_profile')
      .select('*')
      .limit(1)
      .maybeSingle()

    const schoolName = libraryProfile?.name || 'School Library'
    const currency = libraryProfile?.currency || 'KES'
    const receiptNo = payment.receipt_no || `REC-${payment.id.slice(0, 8).toUpperCase()}`
    const formattedAmount = `${currency} ${(payment.amount / 100).toFixed(2)}`
    const paymentDate = new Intl.DateTimeFormat('en-KE', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: libraryProfile?.timezone || 'Africa/Nairobi',
    }).format(new Date(payment.received_at || payment.created_at))

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt ${receiptNo}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; color: #1e293b; }
    .header { border-bottom: 2px solid #0f766e; padding-bottom: 16px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: flex-start; }
    .title { font-size: 24px; font-weight: bold; color: #0f766e; }
    .receipt-badge { font-size: 14px; font-weight: 600; color: #64748b; background: #f1f5f9; padding: 4px 10px; border-radius: 6px; }
    .meta-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px; font-size: 14px; }
    .table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
    .table th { background: #f8fafc; border-bottom: 2px solid #e2e8f0; text-align: left; padding: 12px; font-size: 13px; text-transform: uppercase; }
    .table td { border-bottom: 1px solid #f1f5f9; padding: 12px; font-size: 14px; }
    .total-box { margin-left: auto; width: 280px; background: #f0fdfa; border: 1px solid #ccfbf1; border-radius: 8px; padding: 16px; text-align: right; }
    .total-title { font-size: 14px; color: #0f766e; }
    .total-amount { font-size: 24px; font-weight: bold; color: #115e59; }
    .footer { margin-top: 50px; font-size: 12px; color: #94a3b8; text-align: center; border-top: 1px solid #e2e8f0; padding-top: 16px; }
    @media print { body { margin: 20px; } }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="title">${escapeHtml(schoolName)}</div>
      <div style="color: #64748b; font-size: 14px; margin-top: 4px;">Official Library Payment Receipt</div>
    </div>
    <div class="receipt-badge">RECEIPT #: ${escapeHtml(receiptNo)}</div>
  </div>

  <div class="meta-grid">
    <div>
      <strong>Issued To:</strong><br/>
      ${escapeHtml(payment.borrower?.name || 'Borrower')}<br/>
      Admission / ID: ${escapeHtml(payment.borrower?.admission_number || 'N/A')}<br/>
      Contact: ${escapeHtml(payment.borrower?.email || payment.borrower?.guardian_phone || 'N/A')}
    </div>
    <div>
      <strong>Payment Details:</strong><br/>
      Date: ${escapeHtml(paymentDate)}<br/>
      Received By: ${escapeHtml(payment.receiver?.name || 'Library Staff')}<br/>
      Status: Completed
    </div>
  </div>

  <table class="table">
    <thead>
      <tr>
        <th>Description</th>
        <th>Charge Type</th>
        <th style="text-align: right;">Amount Paid</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          ${escapeHtml(payment.charge?.reason || 'Library Fee/Charge')}<br/>
          ${payment.charge?.issue?.copy?.title?.title ? `<small style="color: #64748b;">Title: ${escapeHtml(payment.charge.issue.copy.title.title)}</small>` : ''}
        </td>
        <td style="text-transform: capitalize;">${escapeHtml(payment.charge?.type || 'Charge')}</td>
        <td style="text-align: right; font-weight: 600;">${escapeHtml(formattedAmount)}</td>
      </tr>
    </tbody>
  </table>

  <div class="total-box">
    <div class="total-title">Total Amount Received</div>
    <div class="total-amount">${escapeHtml(formattedAmount)}</div>
  </div>

  ${payment.notes ? `<p style="margin-top: 24px; font-size: 13px; color: #64748b;"><strong>Notes:</strong> ${escapeHtml(payment.notes)}</p>` : ''}

  <div class="footer">
    Thank you for your payment. Please retain this receipt for your records.<br/>
    Generated electronically by School Library System on ${new Date().toISOString()}
  </div>
</body>
</html>
`

    // Upload to receipts bucket
    const fileName = `receipt-${receiptNo}.html`
    const { error: uploadError } = await supabase.storage
      .from('receipts')
      .upload(fileName, new TextEncoder().encode(html), {
        contentType: 'text/html',
        upsert: true,
      })

    let publicUrl = ''
    if (!uploadError) {
      const { data: pubData } = supabase.storage.from('receipts').getPublicUrl(fileName)
      publicUrl = pubData.publicUrl

      // Update payment receipt_url & receipt_no
      await supabase
        .from('payments')
        .update({ receipt_no: receiptNo, receipt_url: publicUrl })
        .eq('id', payment_id)
    }

    return new Response(
      JSON.stringify({
        success: true,
        receipt_no: receiptNo,
        receipt_url: publicUrl,
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
