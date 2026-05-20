const supabase = require('./src/config/supabase');
async function test() {
  const { data: users, error: e1 } = await supabase.from('users').select('id, email').limit(1);
  const { data: students, error: e2 } = await supabase.from('students').select('id').limit(1);
  console.log("Users:", users, e1);
  console.log("Students:", students, e2);
}
test();
