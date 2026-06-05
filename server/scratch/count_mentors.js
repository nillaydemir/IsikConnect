const supabase = require('/Users/nilaydemir/IsikConnect/server/src/config/supabase').getAdminClient();

async function checkMentors() {
  try {
    const { data: users, error: userError } = await supabase
      .from('users')
      .select('id, first_name, last_name, email, role, is_deleted, is_approved');

    if (userError) throw userError;

    const { data: mentors, error: mentorError } = await supabase
      .from('mentors')
      .select('id, company, job_title, status');

    if (mentorError) throw mentorError;

    console.log('--- USERS WITH ROLE MENTOR (is_deleted = false) ---');
    const userMentors = users.filter(u => u.role === 'mentor' && !u.is_deleted);
    console.log(`Total active user mentors in 'users' table: ${userMentors.length}`);
    userMentors.forEach(u => {
      console.log(`User: ${u.first_name} ${u.last_name} (${u.email}) - ID: ${u.id} - Approved: ${u.is_approved}`);
    });

    console.log('\n--- ENTRIES IN MENTORS TABLE ---');
    console.log(`Total entries in 'mentors' table: ${mentors.length}`);
    mentors.forEach(m => {
      const user = users.find(u => u.id === m.id);
      const name = user ? `${user.first_name} ${user.last_name}` : 'No matching user';
      const email = user ? user.email : 'N/A';
      const isDeleted = user ? user.is_deleted : 'N/A';
      console.log(`Mentor entry: ${name} (${email}) - ID: ${m.id} - Status: ${m.status} - User is_deleted: ${isDeleted}`);
    });

  } catch (err) {
    console.error('Error running check:', err);
  }
}

checkMentors();
