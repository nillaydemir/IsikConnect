require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function test() {
  const res = await supabase.from('users').select('*, students(*), mentors(*)').eq('email', 'student6@test.com').single();
  console.log("Anon response:", JSON.stringify(res.data, null, 2));
  console.log("Anon error:", res.error);
}
test();
