const supabase = require('./src/config/supabase');

async function checkUsersTable() {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Error fetching users:', error);
  } else {
    if (data.length > 0) {
      console.log('Columns in users table:', Object.keys(data[0]));
    } else {
      console.log('No users found to check columns.');
    }
  }
}

checkUsersTable();
