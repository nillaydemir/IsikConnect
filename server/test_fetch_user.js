const supabase = require('./src/config/supabase');
async function test() {
  const { data, error } = await supabase.from('users').select('*, mentors(*), students(*)').limit(3);
  console.log(JSON.stringify(data, null, 2));
}
test();
