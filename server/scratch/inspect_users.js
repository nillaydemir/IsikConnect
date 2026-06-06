const supabase = require('/Users/nilaydemir/IsikConnect/server/src/config/supabase').getAdminClient();

async function inspectUsers() {
  try {
    // 1. Fetch from custom "users" table
    const { data: dbUsers, error: dbUsersError } = await supabase
      .from('users')
      .select('*, mentors(status), students(status)');

    if (dbUsersError) throw dbUsersError;

    console.log('--- Custom users Table ---');
    console.log(JSON.stringify(dbUsers, null, 2));

    // 2. Fetch from auth.users using admin API
    const { data: authUsers, error: authUsersError } = await supabase.auth.admin.listUsers();
    if (authUsersError) throw authUsersError;

    console.log('\n--- Supabase Auth Users ---');
    authUsers.users.forEach(u => {
      console.log({
        id: u.id,
        email: u.email,
        email_confirmed_at: u.email_confirmed_at,
        last_sign_in_at: u.last_sign_in_at,
        created_at: u.created_at
      });
    });

  } catch (err) {
    console.error('Error inspecting users:', err);
  }
}

inspectUsers();
