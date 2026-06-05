const supabase = require('../config/supabase').getAdminClient();

const DEPARTMENT_MATCH_SCORE = 10;
const SKILL_MATCH_SCORE = 5;

// Helper to get start date of current academic year (September 1st)
const getCurrentPeriodStart = () => {
  const now = new Date();
  // September is month index 8 in JS Date (0-indexed)
  if (now.getMonth() >= 8) {
    return new Date(now.getFullYear(), 8, 1);
  } else {
    return new Date(now.getFullYear() - 1, 8, 1);
  }
};

// Helper: Calculate match score
const calculateMatchScore = (studentDetails, mentorUser, mentorProfile) => {
  let score = 0;

  const studentDays = studentDetails.available_days || [];
  const mentorDays = mentorProfile.available_days || [];

  // 1. HARD CONSTRAINT: Must have at least one common available day
  const commonDays = studentDays.filter(day =>
    mentorDays.some(mDay => mDay.trim().toLowerCase() === day.trim().toLowerCase())
  );

  if (commonDays.length === 0) {
    return 0;
  }

  // 2. SKILL MATCH CALCULATION
  const studentTopics = studentDetails.interests || [];
  const mentorSkills = mentorProfile.interests || []; // skills in model = interests in DB

  let skillMatches = 0;
  for (const requirement of studentTopics) {
    const hasMatch = mentorSkills.some(skill =>
      skill.trim().toLowerCase() === requirement.trim().toLowerCase()
    );
    if (hasMatch) {
      skillMatches++;
    }
  }

  // 3. CORE REQUIREMENT: Must have EITHER same department OR at least one matching skill
  const studentDept = (studentDetails.users?.department || studentDetails.department || '').trim().toLowerCase();
  const mentorDept = (mentorUser.department || '').trim().toLowerCase();
  const isDepartmentMatch = studentDept === mentorDept;

  if (!isDepartmentMatch && skillMatches === 0) {
    return 0;
  }

  // 4. SCORING
  if (isDepartmentMatch) {
    score += DEPARTMENT_MATCH_SCORE;
  }

  score += commonDays.length * 5;

  if (skillMatches > 0) {
    score += skillMatches * SKILL_MATCH_SCORE;
  }

  return score;
};

// Helper to count student cancellations
const getStudentCancellations = async (studentId) => {
  const periodStart = getCurrentPeriodStart();
  
  const { data: response, error } = await supabase
    .from('matches')
    .select('id, cancelled_by, mentors(users(is_deleted))')
    .eq('student_id', studentId)
    .eq('status', 'cancelled')
    .gte('created_at', periodStart.toISOString());

  if (error) {
    console.error('Error fetching student cancellations:', error);
    return 0;
  }

  let count = 0;
  for (const match of response) {
    if (match.cancelled_by === 'mentor' || match.cancelled_by === 'admin') {
      continue;
    }

    let mentorsData = match.mentors;
    if (Array.isArray(mentorsData)) {
      if (mentorsData.length === 0) continue;
      mentorsData = mentorsData[0];
    }

    const usersData = mentorsData?.users;
    const isDeleted = Array.isArray(usersData) 
      ? usersData[0]?.is_deleted 
      : usersData?.is_deleted;

    if (isDeleted === true) {
      continue;
    }
    count++;
  }
  return count;
};

// Helper to count mentor cancellations
const getMentorCancellations = async (mentorId) => {
  const periodStart = getCurrentPeriodStart();

  const { data: response, error } = await supabase
    .from('matches')
    .select('id, cancelled_by, students(users(is_deleted))')
    .eq('mentor_id', mentorId)
    .eq('status', 'cancelled')
    .gte('created_at', periodStart.toISOString());

  if (error) {
    console.error('Error fetching mentor cancellations:', error);
    return 0;
  }

  let count = 0;
  for (const match of response) {
    if (match.cancelled_by === 'student' || match.cancelled_by === 'admin') {
      continue;
    }

    let studentsData = match.students;
    if (Array.isArray(studentsData)) {
      if (studentsData.length === 0) continue;
      studentsData = studentsData[0];
    }

    const usersData = studentsData?.users;
    const isDeleted = Array.isArray(usersData)
      ? usersData[0]?.is_deleted
      : usersData?.is_deleted;

    if (isDeleted === true) {
      continue;
    }
    count++;
  }
  return count;
};

// Controller function: Run matching
const runMatching = async (req, res) => {
  const studentId = req.user.id;

  try {
    // 1. Fetch student details
    const { data: studentUser, error: studentError } = await supabase
      .from('users')
      .select('*, students(*)')
      .eq('id', studentId)
      .single();

    if (studentError || !studentUser) {
      return res.status(404).json({ message: 'Student profile not found.' });
    }

    let studentDetails = studentUser.students;
    if (Array.isArray(studentDetails)) {
      studentDetails = studentDetails[0];
    }
    if (!studentDetails) {
      return res.status(404).json({ message: 'Student details not found.' });
    }

    // Attach user model info for department scoring helper
    studentDetails.users = studentUser;

    // 2. Check student's cancellation limit
    const cancelledCount = await getStudentCancellations(studentId);
    if (cancelledCount >= 2) {
      return res.status(400).json({
        message: 'You have used all your matching rights for this academic year.'
      });
    }

    // 3. Fetch approved, non-deleted mentors
    const { data: mentorsRes, error: mentorsError } = await supabase
      .from('users')
      .select('*, mentors(*)')
      .eq('role', 'mentor')
      .eq('is_approved', true);

    if (mentorsError) {
      console.error('Error fetching mentors:', mentorsError);
      return res.status(500).json({ message: 'Failed to fetch mentors.' });
    }

    if (!mentorsRes || mentorsRes.length === 0) {
      return res.status(200).json({ mentor: null, message: 'No approved mentors found.' });
    }

    // 4. Fetch reviews for these mentors
    const mentorIds = mentorsRes.map(r => r.id);
    let allReviews = [];
    try {
      const { data: reviewsData, error: reviewsError } = await supabase
        .from('reviews')
        .select('mentor_id, rating')
        .in('mentor_id', mentorIds);
      if (!reviewsError && reviewsData) {
        allReviews = reviewsData;
      }
    } catch (e) {
      console.warn('Warning: Could not fetch reviews:', e.message);
    }

    // Map reviews by mentor_id
    const reviewsByMentor = {};
    for (const rev of allReviews) {
      const mid = rev.mentor_id.toString();
      const rating = Number(rev.rating);
      if (!reviewsByMentor[mid]) {
        reviewsByMentor[mid] = [];
      }
      reviewsByMentor[mid].push(rating);
    }

    // 5. Fetch cancelled mentors for this student to exclude them
    const { data: studentCancelledMatches, error: scmError } = await supabase
      .from('matches')
      .select('mentor_id')
      .eq('student_id', studentId)
      .eq('status', 'cancelled');

    const excludedMentorIds = new Set(
      (studentCancelledMatches || []).map(m => m.mentor_id.toString())
    );

    // 6. Fetch ALL cancelled matches for limit calculation
    const periodStart = getCurrentPeriodStart();
    const { data: allCancelledMatches, error: acmError } = await supabase
      .from('matches')
      .select('mentor_id, cancelled_by, students(users(is_deleted))')
      .eq('status', 'cancelled')
      .gte('created_at', periodStart.toISOString());

    const mentorCancellationCounts = {};
    for (const match of (allCancelledMatches || [])) {
      const mId = match.mentor_id.toString();
      if (match.cancelled_by === 'student' || match.cancelled_by === 'admin') {
        continue;
      }

      let studentsData = match.students;
      if (Array.isArray(studentsData)) {
        if (studentsData.length === 0) continue;
        studentsData = studentsData[0];
      }

      const usersData = studentsData?.users;
      const isDeleted = Array.isArray(usersData)
        ? usersData[0]?.is_deleted
        : usersData?.is_deleted;

      if (isDeleted === true) {
        continue;
      }

      mentorCancellationCounts[mId] = (mentorCancellationCounts[mId] || 0) + 1;
    }

    // 7. Filter and build mentors list
    const mentorsList = [];
    for (const row of mentorsRes) {
      const mentorIdStr = row.id.toString();

      if (row.is_deleted === true) continue;
      if (excludedMentorIds.has(mentorIdStr)) continue;

      let mentorProfile = row.mentors;
      if (Array.isArray(mentorProfile)) {
        if (mentorProfile.length === 0) continue;
        mentorProfile = mentorProfile[0];
      }
      if (!mentorProfile) continue;

      if (mentorProfile.status === 'deleted') continue;

      const maxCapacity = mentorProfile.max_students || 1;
      const currentCount = mentorProfile.current_student_count || 0;

      // Check capacity limit
      if (currentCount >= maxCapacity) continue;

      // Check cancellation limit
      const mentorCancelCount = mentorCancellationCounts[mentorIdStr] || 0;
      if (mentorCancelCount >= (maxCapacity * 2)) continue;

      // Calculate reviews metrics
      const mentorReviews = reviewsByMentor[row.id.toString()] || [];
      let avgRating = 0.0;
      if (mentorReviews.length > 0) {
        avgRating = mentorReviews.reduce((a, b) => a + b, 0) / mentorReviews.length;
      }
      const reviewCount = mentorReviews.length;

      // Score this mentor
      const matchScore = calculateMatchScore(studentDetails, row, mentorProfile);
      if (matchScore <= 0) continue; // Must pass hard constraints (common day + same dept/matching skill)

      mentorsList.push({
        id: row.id,
        first_name: row.first_name,
        last_name: row.last_name,
        email: row.email,
        profile_image_url: row.profile_image_url,
        department: row.department,
        graduation_year: mentorProfile.graduation_year,
        skills: mentorProfile.interests || [],
        company: mentorProfile.company,
        job_title: mentorProfile.job_title,
        maxCapacity,
        currentStudentsCount: currentCount,
        availableDays: mentorProfile.available_days || [],
        avgRating,
        reviewCount,
        badge: mentorProfile.badge || '🌱 New Mentor',
        matchScore
      });
    }

    // 8. Find the best mentor (Highest matchScore, then by highest avgRating, then by reviewCount)
    if (mentorsList.length === 0) {
      return res.status(200).json({ mentor: null, message: 'No suitable mentor found.' });
    }

    mentorsList.sort((a, b) => {
      if (b.matchScore !== a.matchScore) {
        return b.matchScore - a.matchScore;
      }
      if (b.avgRating !== a.avgRating) {
        return b.avgRating - a.avgRating;
      }
      return b.reviewCount - a.reviewCount;
    });

    const bestMentor = mentorsList[0];

    // 9. Persist matching results in DB
    const mentorId = bestMentor.id;

    // A. Create active match
    const { error: insertMatchError } = await supabase
      .from('matches')
      .insert({
        mentor_id: mentorId,
        student_id: studentId,
        status: 'active'
      });
    if (insertMatchError) throw insertMatchError;

    // B. Increment current student count
    const { error: updateMentorError } = await supabase
      .from('mentors')
      .update({ current_student_count: bestMentor.currentStudentsCount + 1 })
      .eq('id', mentorId);
    if (updateMentorError) throw updateMentorError;

    // C. Update student matched mentor id
    const { error: updateStudentError } = await supabase
      .from('students')
      .update({ matched_mentor_id: mentorId })
      .eq('id', studentId);
    if (updateStudentError) throw updateStudentError;

    res.status(200).json({ mentor: bestMentor, message: 'Mentor matched successfully.' });

  } catch (error) {
    console.error('Matching execution error:', error);
    res.status(500).json({ message: 'Server error during matching process.', error: error.message });
  }
};

// Controller function: Cancel match
const cancelMatch = async (req, res) => {
  const { studentId, mentorId } = req.body;
  const requesterId = req.user.id;
  const requesterRole = req.user.role;

  if (!studentId || !mentorId) {
    return res.status(400).json({ message: 'Student ID and Mentor ID are required.' });
  }

  // Security: Only allow matching participants or admin to cancel
  if (requesterRole !== 'admin' && requesterId !== studentId && requesterId !== mentorId) {
    return res.status(403).json({ message: 'Forbidden: You cannot end this mentorship.' });
  }

  const cancelledBy = requesterRole; // 'student', 'mentor', or 'admin'

  try {
    // 1. UPDATE matches status
    const { error: updateMatchError } = await supabase
      .from('matches')
      .update({
        status: 'cancelled',
        cancelled_by: cancelledBy
      })
      .eq('student_id', studentId)
      .eq('mentor_id', mentorId)
      .eq('status', 'active');

    if (updateMatchError) throw updateMatchError;

    // 2. Decrement current student count of mentor
    const { data: mentorRes, error: mentorError } = await supabase
      .from('mentors')
      .select('current_student_count')
      .eq('id', mentorId)
      .single();

    if (mentorError) throw mentorError;
    const currentCount = mentorRes.current_student_count || 0;
    const newCount = currentCount > 0 ? currentCount - 1 : 0;

    const { error: updateMentorError } = await supabase
      .from('mentors')
      .update({ current_student_count: newCount })
      .eq('id', mentorId);

    if (updateMentorError) throw updateMentorError;

    // 3. Clear student's matched mentor ID
    const { error: updateStudentError } = await supabase
      .from('students')
      .update({ matched_mentor_id: null })
      .eq('id', studentId);

    if (updateStudentError) throw updateStudentError;

    // 4. Send system chat notification if cancelled by student or mentor
    if (cancelledBy !== 'admin') {
      try {
        const senderId = (cancelledBy === 'student') ? studentId : mentorId;
        const receiverId = (cancelledBy === 'student') ? mentorId : studentId;
        await supabase.from('messages').insert({
          sender_id: senderId,
          receiver_id: receiverId,
          content: `Mentorship ended by ${cancelledBy}.`,
          is_read: false
        });
      } catch (msgErr) {
        console.warn('Warning: Could not send system message notification:', msgErr.message);
      }
    }

    res.status(200).json({ message: 'Mentorship ended successfully.' });
  } catch (error) {
    console.error('Cancel matching error:', error);
    res.status(500).json({ message: 'Server error during mentorship termination.', error: error.message });
  }
};

// Controller function: Get student cancelled match count
const getStudentCancelledMatchCount = async (req, res) => {
  const { studentId } = req.params;

  try {
    const count = await getStudentCancellations(studentId);
    res.status(200).json({ count });
  } catch (error) {
    console.error('Error getting student cancelled count:', error);
    res.status(500).json({ message: 'Failed to retrieve cancelled count.' });
  }
};

// Controller function: Get mentor cancelled match count
const getMentorCancelledMatchCount = async (req, res) => {
  const { mentorId } = req.params;

  try {
    const count = await getMentorCancellations(mentorId);
    res.status(200).json({ count });
  } catch (error) {
    console.error('Error getting mentor cancelled count:', error);
    res.status(500).json({ message: 'Failed to retrieve cancelled count.' });
  }
};

module.exports = {
  runMatching,
  cancelMatch,
  getStudentCancelledMatchCount,
  getMentorCancelledMatchCount
};
