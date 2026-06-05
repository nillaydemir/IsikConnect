const supabase = require('./src/config/supabase');

async function run() {
  try {
    // Let's try to query public tables via postgrest if possible, or just list standard tables we know:
    // users, mentors, students, applications, meetings, reviews, workshop_participants.
    // Let's query one row of workshop_participants and other tables to check their columns.
    const tables = ['users', 'mentors', 'students', 'applications', 'meetings', 'reviews', 'workshop_participants', 'meeting_attendance', 'attendance'];
    
    for (const table of tables) {
      const { data, error } = await supabase.from(table).select('*').limit(1);
      if (error) {
        console.log(`Table '${table}' error or does not exist:`, error.message);
      } else {
        console.log(`Table '${table}' columns:`, data.length > 0 ? Object.keys(data[0]) : 'exists but empty');
      }
    }
  } catch (e) {
    console.error(e);
  }
}

run();
