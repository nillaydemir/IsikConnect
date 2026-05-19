const supabase = require('./src/config/supabase');

async function checkStudents() {
  const { data, error } = await supabase.from('students').select('*').limit(3);
  console.log(data);
}
checkStudents();
