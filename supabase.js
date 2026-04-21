import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
export const supabaseAnonKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
