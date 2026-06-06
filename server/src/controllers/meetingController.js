const supabase = require('../config/supabase').getAdminClient();

// Create a meeting (restricted to mentors)
const createMeeting = async (req, res) => {
  const { title, meeting_type, meeting_date, student_id, capacity } = req.body;
  const mentorId = req.user.id;

  if (!title || !meeting_type || !meeting_date) {
    return res.status(400).json({ message: 'Title, type, and date are required.' });
  }

  try {
    const { data, error } = await supabase
      .from('meetings')
      .insert({
        title,
        meeting_type,
        meeting_date,
        mentor_id: mentorId,
        student_id: student_id || null,
        capacity: capacity || null,
        is_deleted: false,
        attended: false
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    console.error('Create meeting error:', error);
    res.status(500).json({ message: 'Failed to create meeting.', error: error.message });
  }
};

// Fetch mentees matched with the logged-in mentor
const getMentees = async (req, res) => {
  const mentorId = req.user.id;
  try {
    const { data, error } = await supabase
      .from('students')
      .select('id, class_level, users(first_name, last_name, email, department, profile_image_url)')
      .eq('matched_mentor_id', mentorId);

    if (error) throw error;

    const mentees = (data || []).map(row => {
      let user = row.users;
      if (Array.isArray(user)) {
        user = user[0];
      }
      return {
        id: row.id,
        class_level: row.class_level || '',
        users: {
          first_name: user?.first_name || 'Mentee',
          last_name: user?.last_name || '',
          email: user?.email || '',
          department: user?.department || '',
          profile_image_url: user?.profile_image_url || null
        }
      };
    });

    res.status(200).json(mentees);
  } catch (error) {
    console.error('Get mentees error:', error);
    res.status(500).json({ message: 'Failed to retrieve mentees.', error: error.message });
  }
};

// Fetch active meetings
const getMeetings = async (req, res) => {
  const userId = req.user.id;
  const role = req.user.role;

  try {
    const { data: meetings, error: meetingsError } = await supabase
      .from('meetings')
      .select('*, mentor:mentor_id(first_name, last_name), student:student_id(first_name, last_name)')
      .eq('is_deleted', false)
      .order('meeting_date', { ascending: true });

    if (meetingsError) throw meetingsError;

    // Check student's workshop registrations
    let registeredMeetingIds = new Set();
    if (role === 'student') {
      const { data: registrations, error: regError } = await supabase
        .from('workshop_participants')
        .select('meeting_id')
        .eq('student_id', userId);
      if (!regError && registrations) {
        registrations.forEach(r => registeredMeetingIds.add(r.meeting_id.toString()));
      }
    }

    const result = (meetings || []).map(meeting => {
      let mentorUser = meeting.mentor;
      if (Array.isArray(mentorUser)) mentorUser = mentorUser[0];
      let studentUser = meeting.student;
      if (Array.isArray(studentUser)) studentUser = studentUser[0];

      return {
        ...meeting,
        mentor: mentorUser ? { first_name: mentorUser.first_name, last_name: mentorUser.last_name } : null,
        student: studentUser ? { first_name: studentUser.first_name, last_name: studentUser.last_name } : null,
        is_registered: registeredMeetingIds.has(meeting.id.toString())
      };
    });

    res.status(200).json(result);
  } catch (error) {
    console.error('Get meetings error:', error);
    res.status(500).json({ message: 'Failed to retrieve meetings.', error: error.message });
  }
};

// Register a student for a workshop
const registerForWorkshop = async (req, res) => {
  const { meetingId } = req.params;
  const studentId = req.user.id;

  try {
    const { data: meeting, error: meetingError } = await supabase
      .from('meetings')
      .select('capacity')
      .eq('id', meetingId)
      .single();

    if (meetingError || !meeting) {
      return res.status(404).json({ message: 'Meeting not found.' });
    }

    const capacity = meeting.capacity;

    const { data: existing, error: existingError } = await supabase
      .from('workshop_participants')
      .select('meeting_id')
      .eq('meeting_id', meetingId)
      .eq('student_id', studentId);

    if (existing && existing.length > 0) {
      return res.status(400).json({ message: 'You are already registered for this workshop.' });
    }

    if (capacity !== null && capacity > 0) {
      const { data: countData, error: countError } = await supabase
        .from('workshop_participants')
        .select('meeting_id')
        .eq('meeting_id', meetingId);

      const currentCount = (countData || []).length;
      if (currentCount >= capacity) {
        return res.status(400).json({ message: 'This workshop has reached its maximum capacity.' });
      }
    }

    const { error: insertError } = await supabase
      .from('workshop_participants')
      .insert({
        meeting_id: meetingId,
        student_id: studentId
      });

    if (insertError) throw insertError;

    res.status(200).json({ message: 'Successfully registered for workshop.' });
  } catch (error) {
    console.error('Register for workshop error:', error);
    res.status(500).json({ message: 'Failed to register for workshop.', error: error.message });
  }
};

// Unregister a student from a workshop
const unregisterFromWorkshop = async (req, res) => {
  const { meetingId } = req.params;
  const studentId = req.user.id;

  try {
    const { error } = await supabase
      .from('workshop_participants')
      .delete()
      .match({ meeting_id: meetingId, student_id: studentId });

    if (error) throw error;

    res.status(200).json({ message: 'Successfully unregistered from workshop.' });
  } catch (error) {
    console.error('Unregister from workshop error:', error);
    res.status(500).json({ message: 'Failed to unregister from workshop.', error: error.message });
  }
};

// Soft-delete a meeting (restricted to mentors)
const deleteMeeting = async (req, res) => {
  const { meetingId } = req.params;
  const mentorId = req.user.id;

  try {
    const { error } = await supabase
      .from('meetings')
      .update({ is_deleted: true })
      .match({ id: meetingId, mentor_id: mentorId });

    if (error) throw error;

    res.status(200).json({ message: 'Meeting soft-deleted successfully.' });
  } catch (error) {
    console.error('Delete meeting error:', error);
    res.status(500).json({ message: 'Failed to delete meeting.', error: error.message });
  }
};

// Update a meeting date/time (restricted to mentors)
const updateMeeting = async (req, res) => {
  const { meetingId } = req.params;
  const { meeting_date } = req.body;
  const mentorId = req.user.id;

  if (!meeting_date) {
    return res.status(400).json({ message: 'New meeting date is required.' });
  }

  const meetingDate = new Date(meeting_date);
  if (meetingDate < new Date()) {
    return res.status(400).json({ message: 'Cannot schedule a meeting in the past.' });
  }

  try {
    const { error } = await supabase
      .from('meetings')
      .update({ meeting_date })
      .match({ id: meetingId, mentor_id: mentorId });

    if (error) throw error;

    res.status(200).json({ message: 'Meeting updated successfully.' });
  } catch (error) {
    console.error('Update meeting error:', error);
    res.status(500).json({ message: 'Failed to update meeting.', error: error.message });
  }
};

// Fetch specific meeting details
const getMeetingDetails = async (req, res) => {
  const { meetingId } = req.params;
  const userId = req.user.id;

  try {
    const { data: meeting, error: meetingError } = await supabase
      .from('meetings')
      .select('*, mentor:mentor_id(first_name, last_name)')
      .eq('id', meetingId)
      .eq('is_deleted', false)
      .single();

    if (meetingError || !meeting) {
      return res.status(404).json({ message: 'Meeting not found.' });
    }

    const { data: registrations, error: regError } = await supabase
      .from('workshop_participants')
      .select('meeting_id')
      .eq('meeting_id', meetingId)
      .eq('student_id', userId);

    let mentorUser = meeting.mentor;
    if (Array.isArray(mentorUser)) mentorUser = mentorUser[0];

    const result = {
      ...meeting,
      mentor: mentorUser ? { first_name: mentorUser.first_name, last_name: mentorUser.last_name } : null,
      is_registered: (registrations && registrations.length > 0)
    };

    res.status(200).json(result);
  } catch (error) {
    console.error('Get meeting details error:', error);
    res.status(500).json({ message: 'Failed to retrieve meeting details.', error: error.message });
  }
};

// Mark meeting attendance
const joinMeeting = async (req, res) => {
  const { meetingId } = req.params;

  try {
    const { error } = await supabase
      .from('meetings')
      .update({ attended: true })
      .eq('id', meetingId);

    if (error) throw error;

    res.status(200).json({ message: 'Attendance marked successfully.' });
  } catch (error) {
    console.error('Join meeting error:', error);
    res.status(500).json({ message: 'Failed to mark attendance.', error: error.message });
  }
};

// Fetch registered students in workshop
const getWorkshopParticipants = async (req, res) => {
  const { meetingId } = req.params;
  const userId = req.user.id;

  try {
    const { data: meeting, error: meetingError } = await supabase
      .from('meetings')
      .select('id, mentor_id, is_deleted')
      .eq('id', meetingId)
      .single();

    if (meetingError || !meeting) {
      return res.status(404).json({ message: 'Meeting not found.' });
    }

    if (meeting.is_deleted) {
      return res.status(400).json({ message: 'Meeting has been deleted.' });
    }

    if (meeting.mentor_id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Access denied: You are not the mentor of this workshop.' });
    }

    const { data: participants, error: regError } = await supabase
      .from('workshop_participants')
      .select('student_id, users:student_id(first_name, last_name, email)')
      .eq('meeting_id', meetingId);

    if (regError) throw regError;

    res.status(200).json(participants || []);
  } catch (error) {
    console.error('Get workshop participants error:', error);
    res.status(500).json({ message: 'Failed to retrieve workshop participants.', error: error.message });
  }
};

module.exports = {
  createMeeting,
  getMentees,
  getMeetings,
  registerForWorkshop,
  unregisterFromWorkshop,
  deleteMeeting,
  updateMeeting,
  getMeetingDetails,
  joinMeeting,
  getWorkshopParticipants
};

