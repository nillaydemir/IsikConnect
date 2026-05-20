const supabase = require('./src/config/supabase');
async function test() {
  const { data, error } = await supabase.rpc('get_policies'); // Supabase doesn't have this built-in easily
  console.log(data, error);
}
test();
