const bcrypt = require('bcrypt');
const supabase = require('../config/supabase');

const deleteAccount = async (req, res) => {
  const { userId } = req.params;

  // Authorization check
  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: You can only delete your own account.' });
  }

  try {
    // 0. Fetch user role
    const { data: userData, error: fetchUserError } = await supabase
      .from('users')
      .select('role')
      .eq('id', userId)
      .maybeSingle();

    if (fetchUserError) throw fetchUserError;
    const userRole = userData?.role;

    // 1. Find active matches for this user
    const { data: activeMatches, error: matchError } = await supabase
      .from('matches')
      .select('id, mentor_id, student_id')
      .or(`student_id.eq.${userId},mentor_id.eq.${userId}`)
      .eq('status', 'active');

    if (matchError) throw matchError;

    if (activeMatches && activeMatches.length > 0) {
      for (const match of activeMatches) {
        // If the deleted user is a student, decrement mentor's active student count
        if (userRole === 'student' && match.student_id === userId) {
          const { data: mentorData } = await supabase
            .from('mentors')
            .select('current_student_count')
            .eq('id', match.mentor_id)
            .maybeSingle();
          
          if (mentorData) {
            const newCount = Math.max(0, (mentorData.current_student_count || 0) - 1);
            await supabase
              .from('mentors')
              .update({ current_student_count: newCount })
              .eq('id', match.mentor_id);
          }
        }
      }
    }

    // Cancel active matches in matches table
    await supabase
      .from('matches')
      .update({ status: 'cancelled' })
      .or(`student_id.eq.${userId},mentor_id.eq.${userId}`)
      .eq('status', 'active');

    // 2. Clear matches relationships in students table
    await supabase.from('students').update({ matched_mentor_id: null }).eq('matched_mentor_id', userId);
    await supabase.from('students').update({ matched_mentor_id: null }).eq('id', userId);

    // 3. Update status to 'deleted' in mentors or students table
    await supabase.from('mentors').update({ status: 'deleted' }).eq('id', userId);
    await supabase.from('students').update({ status: 'deleted' }).eq('id', userId);

    // 4. Clean up meetings to protect the other party
    const nowIso = new Date().toISOString();
    
    // Delete upcoming 1-on-1 meetings involving the deleted user
    await supabase
      .from('meetings')
      .delete()
      .or(`student_id.eq.${userId},mentor_id.eq.${userId}`)
      .eq('meeting_type', '1-on-1')
      .gte('meeting_date', nowIso);

    if (userRole === 'student') {
      // Unregister student from all upcoming workshops
      await supabase
        .from('workshop_participants')
        .delete()
        .eq('student_id', userId);
    } else if (userRole === 'mentor') {
      // Delete upcoming workshops created by this mentor
      await supabase
        .from('meetings')
        .delete()
        .eq('mentor_id', userId)
        .eq('meeting_type', 'Workshop')
        .gte('meeting_date', nowIso);
    }

    // 5. Perform soft-delete in custom "users" table
    const { error: userError } = await supabase
      .from('users')
      .update({ is_deleted: true })
      .eq('id', userId);

    if (userError) throw userError;

    // 5. Disable user in Supabase Auth so they can never log in
    try {
        await supabase.auth.admin.updateUserById(userId, { ban_duration: '87600h' });
    } catch (e) {
        console.warn('Could not disable auth user:', e.message);
    }

    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete Account Error:', error);
    res.status(500).json({ error: error.message });
  }
};

const createSupportTicket = async (req, res) => {
  const { subject, message } = req.body;
  const userId = req.user.id;

  if (!subject || !message) {
    return res.status(400).json({ error: 'Subject and message are required' });
  }

  try {
    // Attempt to insert into support_tickets
    const { error } = await supabase
      .from('support_tickets')
      .insert([
        { user_id: userId, subject, message }
      ]);

    if (error) {
      if (error.code === '42P01') {
        // Table does not exist (relation "support_tickets" does not exist)
        console.warn('support_tickets table does not exist. Please run the SQL to create it.');
        return res.status(500).json({ error: 'Support ticket system is not configured on the backend yet.' });
      }
      throw error;
    }

    res.json({ message: 'Support ticket created successfully' });
  } catch (error) {
    console.error('Create Support Ticket Error:', error);
    res.status(500).json({ error: error.message });
  }
};

const changePassword = async (req, res) => {
  const { newPassword } = req.body;
  const userId = req.user.id;

  if (!newPassword) {
    return res.status(400).json({ error: 'New password is required' });
  }

  try {
    // 1. Update in Supabase Auth using Admin API
    const { data: authData, error: authError } = await supabase.auth.admin.updateUserById(userId, {
      password: newPassword
    });

    if (authError) {
      console.error('Supabase Auth Update Error:', authError);
      return res.status(400).json({ error: authError.message });
    }

    // 2. Also update in custom users table (bcrypt hashed)
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    const { error } = await supabase
      .from('users')
      .update({ password: hashedPassword })
      .eq('id', userId);

    if (error) throw error;

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('Change Password Error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  deleteAccount,
  createSupportTicket,
  changePassword
};
