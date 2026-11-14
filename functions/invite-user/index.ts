// Supabase Edge Function: invite-user
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { requireLibrarian } from '../_shared/auth.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Use POST to invite a user.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const authorization = await requireLibrarian(req, corsHeaders)
    if (authorization instanceof Response) return authorization
    const supabaseAdmin = authorization.supabase

    const { email, name, role, borrower_id } = await req.json()

    if (typeof email !== 'string' || !email.trim() || typeof name !== 'string' || !name.trim()) {
      return new Response(JSON.stringify({ error: 'Email and name are required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const requestedRole = role || 'teacher'
    if (requestedRole !== 'teacher' && requestedRole !== 'librarian') {
      return new Response(JSON.stringify({ error: 'Role must be teacher or librarian.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 1. Create or invite user via Supabase Auth Admin API
    const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      email.trim(),
      { data: { name: name.trim(), role: requestedRole } }
    )

    if (inviteError || !inviteData?.user?.id) {
      throw new Error(inviteError?.message || 'The user invitation could not be created.')
    }
    const userId = inviteData.user.id

    // 2. Insert or update users_profile
    const { error: profileError } = await supabaseAdmin.from('users_profile').upsert({
      id: userId,
      name: name.trim(),
      email: email.trim(),
      role: requestedRole,
      active: true,
      borrower_id: borrower_id || null,
      updated_at: new Date().toISOString(),
    })

    if (profileError) throw profileError

    // 3. Write to audit_log
    await supabaseAdmin.from('audit_log').insert({
      action: 'INVITE_USER',
      entity: 'users_profile',
      entity_id: userId,
      after: { email: email.trim(), name: name.trim(), role: requestedRole, borrower_id },
      timestamp: new Date().toISOString(),
    })

    return new Response(JSON.stringify({ success: true, user_id: userId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
