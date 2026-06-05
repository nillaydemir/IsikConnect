const supabase = require('./src/config/supabase');

async function inspect() {
  try {
    console.log('--- Inspecting database tables ---');
    
    // Get one row from meetings
    const { data: meetings, error: mError } = await supabase
      .from('meetings')
      .select('*')
      .limit(1);
    
    if (mError) {
      console.error('Error fetching meetings:', mError);
    } else {
      console.log('Meetings sample row:', meetings);
    }

    // Get one row from reviews
    const { data: reviews, error: rError } = await supabase
      .from('reviews')
      .select('*')
      .limit(1);
    
    if (rError) {
      console.error('Error fetching reviews:', rError);
    } else {
      console.log('Reviews sample row:', reviews);
    }

    // Get one row from mentors
    const { data: mentors, error: mentorError } = await supabase
      .from('mentors')
      .select('*')
      .limit(1);
    
    if (mentorError) {
      console.error('Error fetching mentors:', mentorError);
    } else {
      console.log('Mentors sample row:', mentors);
    }

    // Get table schemas by querying column names using pg catalog if possible, or just print keys
  } catch (err) {
    console.error('Inspection error:', err);
  }
}

inspect();
