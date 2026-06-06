const supabase = require('../config/supabase').getAdminClient();

const fetchConversations = async (req, res) => {
  const myId = req.user.id;

  try {
    // 1. Fetch matches
    const { data: matchesResponse, error: matchesError } = await supabase
      .from('matches')
      .select('*')
      .or(`student_id.eq.${myId},mentor_id.eq.${myId}`);

    if (matchesError) throw matchesError;

    const mentorshipUserIds = new Set();
    const userActiveStatus = {};
    for (const match of matchesResponse) {
      const otherId = match.student_id === myId ? match.mentor_id : match.student_id;
      const isActive = match.status === 'active';
      mentorshipUserIds.add(otherId);

      if (userActiveStatus[otherId] !== undefined) {
        userActiveStatus[otherId] = userActiveStatus[otherId] || isActive;
      } else {
        userActiveStatus[otherId] = isActive;
      }
    }

    // 2. Fetch job application conversations
    const jobUserIds = new Set();
    try {
      if (req.user.role === 'student') {
        const { data: studentJobApps } = await supabase
          .from('job_applications')
          .select('status, job_postings(mentor_id)')
          .eq('student_id', myId);
        
        if (studentJobApps) {
          for (const app of studentJobApps) {
            const job = app.job_postings;
            if (job && job.mentor_id) {
              const mentorId = job.mentor_id;
              jobUserIds.add(mentorId);
              if (app.status === 'accepted') {
                userActiveStatus[mentorId] = true;
              }
            }
          }
        }
      } else if (req.user.role === 'mentor') {
        const { data: mentorJobApps } = await supabase
          .from('job_applications')
          .select('student_id, status, job_postings(mentor_id)');

        if (mentorJobApps) {
          for (const app of mentorJobApps) {
            const job = app.job_postings;
            if (job && job.mentor_id === myId) {
              const studentId = app.student_id;
              jobUserIds.add(studentId);
              if (app.status === 'accepted') {
                userActiveStatus[studentId] = true;
              }
            }
          }
        }
      }
    } catch (e) {
      console.error('Error fetching job application conversations:', e);
    }

    // 3. Fetch message-based conversations
    const { data: sentMessages, error: sentError } = await supabase
      .from('messages')
      .select('receiver_id')
      .eq('sender_id', myId);

    const { data: receivedMessages, error: receivedError } = await supabase
      .from('messages')
      .select('sender_id')
      .eq('receiver_id', myId);

    if (sentError) throw sentError;
    if (receivedError) throw receivedError;

    const messageUserIds = new Set();
    for (const m of sentMessages || []) {
      messageUserIds.add(m.receiver_id);
    }
    for (const m of receivedMessages || []) {
      messageUserIds.add(m.sender_id);
    }

    for (const uid of messageUserIds) {
      if (userActiveStatus[uid] === undefined) {
        userActiveStatus[uid] = false; // DM-only conversation
      }
    }

    if (Object.keys(userActiveStatus).length === 0) {
      return res.json([]);
    }

    // 4. Fetch profiles
    const { data: usersResponse, error: usersError } = await supabase
      .from('users')
      .select('*')
      .in('id', Object.keys(userActiveStatus));

    if (usersError) throw usersError;

    // 5. Fetch details for each conversation
    const convos = [];
    for (const user of usersResponse) {
      try {
        const { data: msgResponse, error: msgError } = await supabase
          .from('messages')
          .select('*')
          .or(`and(sender_id.eq.${myId},receiver_id.eq.${user.id}),and(sender_id.eq.${user.id},receiver_id.eq.${myId})`)
          .order('created_at', { ascending: false })
          .limit(10);

        if (msgError) throw msgError;

        let lastMsgDoc = null;
        if (msgResponse && msgResponse.length > 0) {
          for (const msg of msgResponse) {
            const isSender = msg.sender_id === myId;
            if (isSender) {
              if (msg.deleted_by_sender !== true) {
                lastMsgDoc = msg;
                break;
              }
            } else {
              if (msg.deleted_by_receiver !== true) {
                lastMsgDoc = msg;
                break;
              }
            }
          }
        }

        let lastMsg = null;
        let lastMsgTime = null;
        let unreadCount = 0;

        if (lastMsgDoc) {
          lastMsg = lastMsgDoc.content;
          lastMsgTime = lastMsgDoc.created_at;

          const { data: unreadResponse, error: unreadError } = await supabase
            .from('messages')
            .select('id')
            .eq('sender_id', user.id)
            .eq('receiver_id', myId)
            .eq('is_read', false);

          if (!unreadError && unreadResponse) {
            unreadCount = unreadResponse.length;
          }
        }

        const isActive = userActiveStatus[user.id] || false;

        // If not active match/convo and no message history, skip
        if (!isActive && lastMsg === null) continue;

        let label = null;
        if (user.role === 'admin') {
          label = 'Support';
        } else if (jobUserIds.has(user.id)) {
          label = 'Job';
        } else if (mentorshipUserIds.has(user.id)) {
          if (req.user.role === 'mentor') {
            label = 'Mentee';
          } else if (req.user.role === 'student') {
            label = 'Mentor';
          }
        } else {
          if (user.role === 'mentor') {
            label = 'Mentor';
          } else if (user.role === 'student') {
            label = 'Mentee';
          }
        }

        convos.push({
          targetUser: user,
          lastMessage: lastMsg,
          lastMessageTime: lastMsgTime,
          unreadCount: unreadCount,
          isActiveMatch: isActive,
          label: label
        });
      } catch (err) {
        console.error(`Error loading convo details for ${user.id}:`, err);
      }
    }

    // Sort by lastMessageTime descending
    convos.sort((a, b) => {
      if (!a.lastMessageTime && !b.lastMessageTime) return 0;
      if (!a.lastMessageTime) return 1;
      if (!b.lastMessageTime) return -1;
      return new Date(b.lastMessageTime) - new Date(a.lastMessageTime);
    });

    res.json(convos);
  } catch (error) {
    console.error('Fetch conversations error:', error);
    res.status(500).json({ message: 'Server error loading chat list.' });
  }
};

const fetchChat = async (req, res) => {
  const myId = req.user.id;
  const { targetUserId } = req.params;

  try {
    const { data: messages, error } = await supabase
      .from('messages')
      .select('*')
      .or(`and(sender_id.eq.${myId},receiver_id.eq.${targetUserId}),and(sender_id.eq.${targetUserId},receiver_id.eq.${myId})`)
      .order('created_at', { ascending: true });

    if (error) throw error;

    // Filter soft-deleted messages
    const filtered = (messages || []).filter(msg => {
      if (msg.sender_id === myId) {
        return msg.deleted_by_sender !== true;
      } else {
        return msg.deleted_by_receiver !== true;
      }
    });

    res.json(filtered);
  } catch (error) {
    console.error('Fetch chat error:', error);
    res.status(500).json({ message: 'Server error loading messages' });
  }
};

const sendMessage = async (req, res) => {
  const myId = req.user.id;
  const { receiver_id, content } = req.body;

  try {
    // 1. Verify recipient is not deleted
    const { data: targetUser, error: userError } = await supabase
      .from('users')
      .select('role, is_deleted')
      .eq('id', receiver_id)
      .single();

    if (userError || !targetUser) {
      return res.status(404).json({ message: 'Recipient not found' });
    }

    if (targetUser.is_deleted === true) {
      return res.status(400).json({ message: 'User has deleted their account' });
    }

    // 2. If target is admin, bypass matches check (Support chats are always allowed)
    if (targetUser.role !== 'admin' && req.user.role !== 'admin') {
      // Check if match exists and is active
      const { data: activeMatch, error: matchError } = await supabase
        .from('matches')
        .select('id')
        .or(`and(student_id.eq.${myId},mentor_id.eq.${receiver_id}),and(student_id.eq.${receiver_id},mentor_id.eq.${myId})`)
        .eq('status', 'active')
        .maybeSingle();

      let isActiveConnection = !!activeMatch;

      // If no active mentorship match, check accepted job applications
      if (!isActiveConnection) {
        try {
          const mentorId = req.user.role === 'mentor' ? myId : receiver_id;
          const studentId = req.user.role === 'mentor' ? receiver_id : myId;

          const { data: jobApps } = await supabase
            .from('job_applications')
            .select('id, job_postings(mentor_id)')
            .eq('student_id', studentId)
            .eq('status', 'accepted');

          if (jobApps) {
            for (const app of jobApps) {
              const job = app.job_postings;
              if (job && job.mentor_id === mentorId) {
                isActiveConnection = true;
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (!isActiveConnection) {
        return res.status(403).json({ message: 'You can only message active matches' });
      }
    }

    // 3. Insert message
    const { data: message, error: sendError } = await supabase
      .from('messages')
      .insert({
        sender_id: myId,
        receiver_id,
        content,
        is_read: false
      })
      .select()
      .single();

    if (sendError) throw sendError;

    res.status(201).json(message);
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ message: 'Server error sending message' });
  }
};

const markAsRead = async (req, res) => {
  const myId = req.user.id;
  const { senderId } = req.body;

  try {
    const { error } = await supabase
      .from('messages')
      .update({ is_read: true })
      .eq('sender_id', senderId)
      .eq('receiver_id', myId)
      .eq('is_read', false);

    if (error) throw error;

    res.json({ message: 'Messages marked as read' });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ message: 'Server error marking messages as read' });
  }
};

const deleteChat = async (req, res) => {
  const myId = req.user.id;
  const { targetUserId } = req.body;

  try {
    // 1. Soft delete sent messages
    await supabase
      .from('messages')
      .update({ deleted_by_sender: true })
      .eq('sender_id', myId)
      .eq('receiver_id', targetUserId);

    // 2. Soft delete received messages
    await supabase
      .from('messages')
      .update({ deleted_by_receiver: true })
      .eq('sender_id', targetUserId)
      .eq('receiver_id', myId);

    res.json({ message: 'Chat history deleted successfully' });
  } catch (error) {
    console.error('Delete chat error:', error);
    res.status(500).json({ message: 'Server error deleting chat' });
  }
};

const checkConnectionStatus = async (req, res) => {
  const myId = req.user.id;
  const { targetUserId } = req.params;

  try {
    const { data: targetUser, error: userError } = await supabase
      .from('users')
      .select('is_deleted, role')
      .eq('id', targetUserId)
      .single();

    if (userError || !targetUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    const isTargetUserDeleted = targetUser.is_deleted === true;

    // Check matches
    const { data: activeMatch, error: matchError } = await supabase
      .from('matches')
      .select('id')
      .or(`and(student_id.eq.${myId},mentor_id.eq.${targetUserId}),and(student_id.eq.${targetUserId},mentor_id.eq.${myId})`)
      .eq('status', 'active')
      .maybeSingle();

    let isActiveConnection = !!activeMatch;

    // Check job apps if needed
    if (!isActiveConnection && targetUser.role !== 'admin' && req.user.role !== 'admin') {
      try {
        const mentorId = req.user.role === 'mentor' ? myId : targetUserId;
        const studentId = req.user.role === 'mentor' ? targetUserId : myId;

        const { data: jobApps } = await supabase
          .from('job_applications')
          .select('id, job_postings(mentor_id)')
          .eq('student_id', studentId)
          .eq('status', 'accepted');

        if (jobApps) {
          for (const app of jobApps) {
            const job = app.job_postings;
            if (job && job.mentor_id === mentorId) {
              isActiveConnection = true;
              break;
            }
          }
        }
      } catch (_) {}
    }

    // Support chats are always active connection
    if (targetUser.role === 'admin' || req.user.role === 'admin') {
      isActiveConnection = true;
    }

    res.json({
      isActiveMatch: isActiveConnection,
      isTargetUserDeleted: isTargetUserDeleted
    });
  } catch (error) {
    console.error('Check connection status error:', error);
    res.status(500).json({ message: 'Server error checking connection status' });
  }
};

module.exports = {
  fetchConversations,
  fetchChat,
  sendMessage,
  markAsRead,
  deleteChat,
  checkConnectionStatus
};
