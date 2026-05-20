const supabase = require('./src/config/supabase');

async function testFetch() {
  // Get an active match mentee ID
  const { data: mentees, error: menteeError } = await supabase.from('students').select('*, users(*)').not('matched_mentor_id', 'is', null).limit(1);
  if (!mentees || mentees.length === 0) {
    console.log("No mentees found");
    return;
  }
  const targetUserId = mentees[0].id;
  console.log("Found Mentee ID:", targetUserId);

  const { data: response, error } = await supabase.from('users').select('*, mentors(*), students(*)').eq('id', targetUserId).single();
  if (error) {
    console.error("Error fetching user:", error);
    return;
  }
  console.log("Raw user response:", JSON.stringify(response, null, 2));
}
testFetch();
