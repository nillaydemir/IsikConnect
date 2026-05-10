const supabase = require('../config/supabase');

const deleteAccount = async (req, res) => {
  const { userId } = req.params;

  // Authorization check
  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: You can only delete your own account.' });
  }

  try {
    // Note: If you have foreign keys set to ON DELETE CASCADE in Supabase, 
    // deleting the user from the `users` table will automatically delete related records 
    // in `mentors`, `students`, `matches`, and `messages`.
    // If not, we should manually delete them. Let's do it manually just to be safe.

    // 1. Delete from messages where user is sender or receiver
    await supabase.from('messages').delete().or(`sender_id.eq.${userId},receiver_id.eq.${userId}`);

    // 2. Delete matches where user is student or mentor
    await supabase.from('matches').delete().or(`student_id.eq.${userId},mentor_id.eq.${userId}`);

    // 3. Delete from mentors or students table
    await supabase.from('mentors').delete().eq('user_id', userId);
    await supabase.from('students').delete().eq('user_id', userId);

    // 4. Delete the user from the users table
    const { error: userError } = await supabase.from('users').delete().eq('id', userId);

    if (userError) throw userError;

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

module.exports = {
  deleteAccount,
  createSupportTicket
};
