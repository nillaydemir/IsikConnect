const supabase = require('./src/config/supabase');
async function test() {
  const { data: users, error: e1 } = await supabase.from('users').select('*, mentors(*), students(*)').order('created_at', { ascending: false }).limit(5);
  console.log(JSON.stringify(users, null, 2));
}
test();
