const supabase = require('../config/supabase').getAdminClient();

const listPendingApplications = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('applications')
      .select(`
        *,
        users (
          first_name, last_name, email, phone, department
        )
      `)
      .eq('status', 'pending');

    if (error) throw error;

    let enrichedData = [];
    for (const app of data) {
      try {
        // Fetch user auth details using Admin API to check email confirmation status
        const { data: authUserData, error: authUserError } = await supabase.auth.admin.getUserById(app.user_id);
        if (authUserError || !authUserData || !authUserData.user || !authUserData.user.email_confirmed_at) {
          // Skip application if email is not verified yet
          continue;
        }

        if (app.role === 'student') {
          const { data: student } = await supabase.from('students').select('class_level').eq('id', app.user_id).single();
          enrichedData.push({ ...app, specific: { ...student, department: app.users.department } });
        } else if (app.role === 'mentor') {
          const { data: mentor } = await supabase.from('mentors').select('company, job_title').eq('id', app.user_id).single();
          enrichedData.push({ ...app, specific: { ...mentor, department: app.users.department } });
        } else {
          enrichedData.push({ ...app });
        }
      } catch (err) {
        console.error(`Error processing pending application for user ${app.user_id}:`, err);
      }
    }

    res.json(enrichedData);
  } catch (error) {
    console.error('List pending applications error:', error);
    res.status(500).json({ message: 'Server error fetching pending applications' });
  }
};

const updateApplicationStatus = async (req, res) => {
  const { applicationId, status } = req.body;

  try {
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const { data: app, error: fetchError } = await supabase
      .from('applications')
      .select('*')
      .eq('id', applicationId)
      .single();

    if (fetchError || !app) throw fetchError || new Error("App not found");

    await supabase.from('applications').update({ status }).eq('id', applicationId);
    await supabase.from('users').update({ is_approved: status === 'approved' }).eq('id', app.user_id);
    
    if (app.role === 'student' || app.role === 'mentor') {
      const table = app.role === 'student' ? 'students' : 'mentors';
      await supabase.from(table).update({ status }).eq('id', app.user_id);
    }

    res.json({ message: `Application ${status}` });
  } catch (error) {
    console.error('App update error:', error);
    res.status(500).json({ message: 'Server error updating status' });
  }
};

const fetchUsers = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .not('role', 'eq', 'admin')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('Fetch users error:', error);
    res.status(500).json({ message: 'Server error fetching users' });
  }
};

const updateUserField = async (req, res) => {
  const { userId } = req.params;
  const { field, value } = req.body;

  try {
    const { error: updateError } = await supabase
      .from('users')
      .update({ [field]: value })
      .eq('id', userId);

    if (updateError) throw updateError;

    if (field === 'is_deleted' && value === true) {
      const { data: user, error: roleError } = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .single();

      if (roleError) throw roleError;

      if (user.role === 'student') {
        const { data: matches, error: matchesError } = await supabase
          .from('matches')
          .select('*')
          .eq('student_id', userId)
          .eq('status', 'active');

        if (matchesError) throw matchesError;

        for (const match of matches) {
          const mentorId = match.mentor_id;
          
          await supabase
            .from('matches')
            .update({ status: 'cancelled', cancelled_by: 'admin' })
            .eq('id', match.id);

          const { data: mentor, error: mentorFetchError } = await supabase
            .from('mentors')
            .select('current_student_count')
            .eq('id', mentorId)
            .maybeSingle();

          if (!mentorFetchError && mentor) {
            const currentCount = mentor.current_student_count || 0;
            await supabase
              .from('mentors')
              .update({ current_student_count: currentCount > 0 ? currentCount - 1 : 0 })
              .eq('id', mentorId);
          }
        }

        await supabase
          .from('students')
          .update({ matched_mentor_id: null })
          .eq('id', userId);

      } else if (user.role === 'mentor') {
        const { data: matches, error: matchesError } = await supabase
          .from('matches')
          .select('*')
          .eq('mentor_id', userId)
          .eq('status', 'active');

        if (matchesError) throw matchesError;

        for (const match of matches) {
          const studentId = match.student_id;

          await supabase
            .from('matches')
            .update({ status: 'cancelled', cancelled_by: 'admin' })
            .eq('id', match.id);

          await supabase
            .from('students')
            .update({ matched_mentor_id: null })
            .eq('id', studentId);
        }

        await supabase
          .from('mentors')
          .update({ current_student_count: 0 })
          .eq('id', userId);
      }
    }

    res.json({ message: 'User updated successfully' });
  } catch (error) {
    console.error('Update user field error:', error);
    res.status(500).json({ message: error.message || 'Server error updating user field' });
  }
};

const fetchStats = async (req, res) => {
  try {
    const { data: sRes, error: sErr } = await supabase.from('users').select('id').eq('role', 'student').eq('is_deleted', false).eq('is_approved', true);
    if (sErr) throw sErr;

    const { data: mRes, error: mErr } = await supabase.from('users').select('id').eq('role', 'mentor').eq('is_deleted', false).eq('is_approved', true);
    if (mErr) throw mErr;

    const { data: wRes, error: wErr } = await supabase.from('forum_posts').select('id').eq('category', 'Workshops');
    if (wErr) throw wErr;

    const { data: tRes, error: tErr } = await supabase.from('support_tickets').select('id');
    if (tErr) throw tErr;

    const { data: otRes, error: otErr } = await supabase.from('support_tickets').select('id').not('status', 'eq', 'resolved');
    if (otErr) throw otErr;

    const { data: amtRes, error: amtErr } = await supabase
      .from('matches')
      .select('id, mentor_id, student_id, mentors(users(first_name, last_name, email, profile_image_url)), students(users(first_name, last_name, email, profile_image_url))')
      .eq('status', 'active');
    if (amtErr) throw amtErr;

    res.json({
      studentCount: sRes.length,
      mentorCount: mRes.length,
      workshopCount: wRes.length,
      ticketCount: tRes.length,
      openTicketCount: otRes.length,
      activeMatchCount: amtRes.length,
      activeMatches: amtRes
    });
  } catch (error) {
    console.error('Fetch stats error:', error);
    res.status(500).json({ message: 'Server error compiling statistics' });
  }
};

const fetchSupportTickets = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('support_tickets')
      .select('*, users(first_name, last_name, email, id, is_deleted)')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('Fetch support tickets error:', error);
    res.status(500).json({ message: 'Server error fetching support tickets' });
  }
};

const fetchReviews = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('reviews')
      .select('*, mentor:mentors(users(first_name, last_name)), student:students(users(first_name, last_name))')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('Fetch reviews error:', error);
    res.status(500).json({ message: 'Server error fetching reviews' });
  }
};

const updateTicket = async (req, res) => {
  const { ticketId } = req.params;
  const updateData = req.body;

  try {
    const { data, error } = await supabase
      .from('support_tickets')
      .update(updateData)
      .eq('id', ticketId);

    if (error) throw error;
    res.json({ message: 'Ticket updated successfully' });
  } catch (error) {
    console.error('Update ticket error:', error);
    res.status(500).json({ message: 'Server error updating ticket' });
  }
};

const sendAdminMessage = async (req, res) => {
  const { receiver_id, content } = req.body;
  const sender_id = req.user.id;

  try {
    const { data, error } = await supabase
      .from('messages')
      .insert({
        sender_id,
        receiver_id,
        content,
        is_read: false
      });

    if (error) throw error;
    res.json({ message: 'Message sent successfully' });
  } catch (error) {
    console.error('Send admin message error:', error);
    res.status(500).json({ message: 'Server error sending message' });
  }
};

module.exports = {
  listPendingApplications,
  updateApplicationStatus,
  fetchUsers,
  updateUserField,
  fetchStats,
  fetchSupportTickets,
  fetchReviews,
  updateTicket,
  sendAdminMessage
};
