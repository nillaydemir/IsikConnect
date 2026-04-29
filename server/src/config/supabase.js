const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../../server/.env') }); // Point to server/.env if needed, but since it's already loaded in server.js, we just use process.env
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.warn('Supabase URL or Key missing in environment variables');
}

// CRITICAL: Disable auth persistence on the server so signInWithPassword doesn't pollute the global service_role client.
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false
  }
});

module.exports = supabase;
