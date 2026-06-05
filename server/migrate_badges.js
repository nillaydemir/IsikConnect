const supabase = require('./src/config/supabase');
const { calculateAndUpdateMentorBadge } = require('./src/controllers/studentController');

async function migrate() {
  console.log('Starting mentor badge migration...');
  
  try {
    // 1. Fetch all mentors
    const { data: mentors, error: mentorsError } = await supabase
      .from('mentors')
      .select('id');
      
    if (mentorsError) {
      console.error('Error fetching mentors:', mentorsError);
      process.exit(1);
    }
    
    console.log(`Found ${mentors.length} mentors to process.`);
    
    for (const mentor of mentors) {
      const mentorId = mentor.id;
      console.log(`Recalculating badge for mentor: ${mentorId}`);
      try {
        const result = await calculateAndUpdateMentorBadge(mentorId);
        console.log(`Successfully updated mentor ${mentorId}. Badge: ${result.badge}, Avg Rating: ${result.avgRating.toFixed(2)} (${result.totalRatings} ratings)`);
      } catch (err) {
        console.error(`Failed to update mentor ${mentorId}:`, err.message);
      }
    }
    
    console.log('Mentor badge migration completed successfully!');
    process.exit(0);
  } catch (e) {
    console.error('Unexpected migration error:', e);
    process.exit(1);
  }
}

migrate();
