const supabase = require('./src/config/supabase');

async function checkUsers() {
  const { data, error } = await supabase.from('users').select('*').limit(3);
  console.log(data);
}
checkUsers();
