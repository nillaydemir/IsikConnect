const supabase = require('../config/supabase');

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
      if (app.role === 'student') {
        const { data: student } = await supabase.from('students').select('class_level').eq('id', app.user_id).single();
        enrichedData.push({ ...app, specific: { ...student, department: app.users.department } });
      } else if (app.role === 'mentor') {
        const { data: mentor } = await supabase.from('mentors').select('company, job_title').eq('id', app.user_id).single();
        enrichedData.push({ ...app, specific: { ...mentor, department: app.users.department } });
      } else {
        enrichedData.push({ ...app });
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

module.exports = {
  listPendingApplications,
  updateApplicationStatus
};
