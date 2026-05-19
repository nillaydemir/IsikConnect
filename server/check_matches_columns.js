const supabase = require('./src/config/supabase');

async function checkMatchesTable() {
  const { data, error } = await supabase
    .from('matches')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Error fetching matches:', error);
  } else {
    if (data.length > 0) {
      console.log('Columns in matches table:', Object.keys(data[0]));
      console.log('Sample data:', data[0]);
    } else {
      console.log('No matches found to check columns.');
    }
  }
}

checkMatchesTable();
