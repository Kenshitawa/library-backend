// Supabase Edge Function: set-user-active
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
      return new Response(JSON.stringify({ error: 'Use POST to update a user.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const authorization = await requireLibrarian(req, corsHeaders)
    if (authorization instanceof Response) return authorization
    const supabaseAdmin = authorization.supabase
    const { user_id, active } = await req.json()

    if (typeof user_id !== 'string' || typeof active !== 'boolean') {
      return new Response(JSON.stringify({ error: 'user_id and active boolean are required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Guard 1: Cannot deactivate own account
    if (!active && authorization.userId === user_id) {
      return new Response(
        JSON.stringify({ error: 'You cannot deactivate your own staff account.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Guard 2: Cannot deactivate the last active librarian
    if (!active) {
      const { data: targetProfile } = await supabaseAdmin
        .from('users_profile')
        .select('role')
        .eq('id', user_id)
        .single()

      if (targetProfile?.role === 'librarian') {
        const { count: activeLibrarians } = await supabaseAdmin
          .from('users_profile')
          .select('*', { count: 'exact', head: true })
          .eq('role', 'librarian')
          .eq('active', true)

        if ((activeLibrarians ?? 0) <= 1) {
          return new Response(
            JSON.stringify({
              error: 'Cannot deactivate the last active librarian. At least one active librarian must remain.',
            }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
      }
    }

    // Update active status
    const { error: updateError } = await supabaseAdmin
      .from('users_profile')
      .update({ active, updated_at: new Date().toISOString() })
      .eq('id', user_id)

    if (updateError) throw updateError

    // If deactivating, sign out user sessions
    if (!active) {
      try {
        await supabaseAdmin.auth.admin.signOut(user_id)
      } catch (err) {
        console.warn('Could not revoke active sessions:', err)
      }
    }

    // Write audit log
    await supabaseAdmin.from('audit_log').insert({
      action: active ? 'REACTIVATE_USER' : 'DEACTIVATE_USER',
      entity: 'users_profile',
      entity_id: user_id,
      after: { active },
      timestamp: new Date().toISOString(),
    })

    return new Response(JSON.stringify({ success: true, active }), {
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
