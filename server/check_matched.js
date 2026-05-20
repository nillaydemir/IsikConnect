const supabase = require('./src/config/supabase');

async function checkMatched() {
  const { data, error } = await supabase.from('students').select('*').not('matched_mentor_id', 'is', null);
  console.log("Matched students:", data);
}
checkMatched();
