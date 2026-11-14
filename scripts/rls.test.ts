import { describe, it, expect } from 'vitest'
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.SUPABASE_URL || 'http://127.0.0.1:54342'
const ANON_KEY = process.env.SUPABASE_ANON_KEY

if (!ANON_KEY) {
  throw new Error('Set SUPABASE_ANON_KEY to the local public Supabase key before running RLS tests.')
}

describe('RLS Policy Verification', () => {
  const anonClient = createClient(supabaseUrl, ANON_KEY)

  it('allows anonymous read on titles', async () => {
    const { data, error } = await anonClient
      .from('titles')
      .select('id, title')
      .limit(5)
    
    expect(error).toBeNull()
    expect(Array.isArray(data)).toBe(true)
  })

  it('blocks anonymous write to borrowers', async () => {
    const { data, error } = await anonClient
      .from('borrowers')
      .insert({
        borrower_no: 'TEST-UNAUTH-001',
        name: 'Unauthorized Insertion Test'
      })

    expect(error).not.toBeNull()
  })

  it('blocks anonymous access to audit_log', async () => {
    const { data, error } = await anonClient
      .from('audit_log')
      .select('*')

    expect(error).not.toBeNull()
  })
})
