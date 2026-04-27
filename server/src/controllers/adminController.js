const supabase = require('../config/supabase');

const listPendingMentors = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('mentors')
      .select('*')
      .eq('status', 'pending');

    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('List pending mentors error:', error);
    res.status(500).json({ message: 'Server error fetching pending mentors' });
  }
};

const approveMentor = async (req, res) => {
  const { mentorId, status } = req.body; // status: 'approved' or 'rejected'

  try {
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const { error: mentorUpdateError } = await supabase
      .from('mentors')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', mentorId);

    if (mentorUpdateError) throw mentorUpdateError;
    
    // Also update users table if needed
    const isApproved = status === 'approved';
    const { error: userUpdateError } = await supabase
      .from('users')
      .update({ is_approved: isApproved })
      .eq('id', mentorId);

    if (userUpdateError) throw userUpdateError;

    res.json({ message: `Mentor ${status} successfully` });
  } catch (error) {
    console.error('Approve mentor error:', error);
    res.status(500).json({ message: 'Server error updating mentor status' });
  }
};

module.exports = {
  listPendingMentors,
  approveMentor
};
