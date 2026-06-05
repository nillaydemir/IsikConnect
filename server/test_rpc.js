const supabase = require('./src/config/supabase');

async function run() {
  try {
    const { data, error } = await supabase.rpc('exec_sql', { sql: 'SELECT 1;' });
    console.log('Result of exec_sql:', data, error);
  } catch (e) {
    console.error('Error calling exec_sql:', e);
  }
}

run();
