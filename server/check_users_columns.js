const supabase = require('./src/config/supabase');

async function checkTables() {
  const { data: students, error: e1 } = await supabase.from('students').select('*').limit(1);
  const { data: mentors, error: e2 } = await supabase.from('mentors').select('*').limit(1);
  
  if (students && students.length > 0) console.log('Students:', Object.keys(students[0]));
  if (mentors && mentors.length > 0) console.log('Mentors:', Object.keys(mentors[0]));
}
checkTables();
