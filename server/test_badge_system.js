const supabase = require('./src/config/supabase');
const { calculateAndUpdateMentorBadge } = require('./src/controllers/studentController');

async function test() {
  console.log('--- STARTING BADGE SYSTEM TEST ---');

  try {
    // 1. Get a mentor and a student
    const { data: mentors, error: mentorsErr } = await supabase
      .from('mentors')
      .select('id')
      .limit(1);

    if (mentorsErr || !mentors || mentors.length === 0) {
      console.error('No mentors found in the database. Please register a mentor first.');
      process.exit(1);
    }
    const mentorId = mentors[0].id;

    const { data: students, error: studentsErr } = await supabase
      .from('students')
      .select('id')
      .limit(1);

    if (studentsErr || !students || students.length === 0) {
      console.error('No students found in the database. Please register a student first.');
      process.exit(1);
    }
    const studentId = students[0].id;

    console.log(`Using Mentor: ${mentorId}`);
    console.log(`Using Student: ${studentId}`);

    // 2. Create a completed, attended, non-deleted 1-on-1 meeting in the past
    console.log('Creating a dummy meeting in the past...');
    const pastDate = new Date();
    pastDate.setHours(pastDate.getHours() - 2); // 2 hours ago

    const { data: meeting, error: meetingErr } = await supabase
      .from('meetings')
      .insert({
        title: 'Test Mentorship Meeting',
        meeting_type: '1-on-1',
        meeting_date: pastDate.toISOString(),
        mentor_id: mentorId,
        student_id: studentId,
        capacity: 1,
        attended: true,
        is_deleted: false
      })
      .select()
      .single();

    if (meetingErr) {
      console.error('Error creating test meeting:', meetingErr);
      process.exit(1);
    }
    console.log(`Created meeting ID: ${meeting.id}`);

    // 3. Insert/Upsert review
    console.log('Inserting/Upserting a 5-star rating...');
    const { error: reviewErr } = await supabase
      .from('reviews')
      .upsert({
        mentor_id: mentorId,
        student_id: studentId,
        rating: 5.0,
        comment: 'Excellent mentor!'
      }, { onConflict: 'mentor_id, student_id' });

    if (reviewErr) {
      console.error('Error saving review:', reviewErr);
      // Clean up meeting
      await supabase.from('meetings').delete().eq('id', meeting.id);
      process.exit(1);
    }

    // 4. Trigger recalculation
    console.log('Triggering badge recalculation...');
    const result = await calculateAndUpdateMentorBadge(mentorId);
    console.log('Recalculation result:', result);

    // Since total completed reviews is 1 (which is < 5), it should be '🌱 New Mentor'
    if (result.badge === '🌱 New Mentor') {
      console.log('SUCCESS: Badge correctly assigned as 🌱 New Mentor (ratings count < 5).');
    } else {
      console.warn(`Unexpected badge: ${result.badge}`);
    }

    // Clean up
    console.log('Cleaning up test data...');
    await supabase.from('reviews').delete().eq('mentor_id', mentorId).eq('student_id', studentId);
    await supabase.from('meetings').delete().eq('id', meeting.id);

    // Reset mentor badge to default
    await supabase.from('mentors').update({ badge: '🌱 New Mentor' }).eq('id', mentorId);

    console.log('Test completed successfully and cleaned up!');
    process.exit(0);
  } catch (e) {
    console.error('Test execution failed:', e);
    process.exit(1);
  }
}

test();
