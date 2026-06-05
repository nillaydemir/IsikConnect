const supabase = require('./src/config/supabase');

async function run() {
  try {
    const { data, error } = await supabase.rpc('exec_sql', { 
      sql: "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies WHERE tablename = 'matches';" 
    });
    console.log('Matches table policies:', data || error);
  } catch (e) {
    console.error('Error fetching policies:', e);
  }
}

run();
