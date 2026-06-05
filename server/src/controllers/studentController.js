const supabase = require('../config/supabase');
const jwt = require('jsonwebtoken');

const BUCKET_NAME = 'documents'; // or you can use 'student-docs' if you have created one

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
};

const registerStudent = async (req, res) => {
  console.log('--- [DEBUG] Registering Student Request ---');

  let { full_name, email, password, department, class_level, interests, available_days, phone } = req.body;

  // Handle JSON strings from multipart form-data
  try {
    if (typeof available_days === 'string') available_days = JSON.parse(available_days);
    if (typeof interests === 'string') interests = JSON.parse(interests);
  } catch (e) {
    console.warn('Failed to parse JSON fields:', e);
    available_days = available_days || [];
    interests = interests || [];
  }

  // Validation
  if (!email || !password || !full_name) {
    return res.status(400).json({ message: "Email, password, and full name are required." });
  }
  if (!email.toLowerCase().endsWith('@isik.edu.tr')) {
    return res.status(400).json({ message: "Only @isik.edu.tr email addresses are allowed for student registration." });
  }
  if (!req.file) {
    return res.status(400).json({ message: "Student document (öğrenci belgesi) is required." });
  }

  try {
    let student_doc_url = '';

    // 1. File upload
    const file = req.file;
    // Sanitize file name to prevent Supabase upload errors (e.g. invalid characters)
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    const fileName = `${Date.now()}_${sanitizedName}`;
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from(BUCKET_NAME)
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: false
      });

    if (uploadError) {
      console.error('File upload error:', uploadError);
      throw { stage: 'file_upload', message: uploadError.message, details: uploadError.details, hint: uploadError.hint };
    }

    const { data: publicUrlData } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(uploadData.path);

    student_doc_url = publicUrlData.publicUrl;

    // 2. Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: false
    });

    if (authError) {
      console.error('Supabase Auth error:', authError);
      return res.status(400).json({ message: authError.message });
    }

    // Trigger email verification manually because admin.createUser doesn't send it automatically
    const { error: resendError } = await supabase.auth.resend({
      type: 'signup',
      email: email
    });

    if (resendError) {
      console.error('Supabase Resend error:', resendError);
    }

    const userId = authData.user.id;

    // First and last name extraction (since we receive full_name)
    const nameParts = full_name.trim().split(' ');
    const firstName = nameParts[0];
    const lastName = nameParts.slice(1).join(' ') || '';

    // 3. Insert into "users" table
    const { error: insertUserError } = await supabase
      .from('users')
      .insert([{
        id: userId,
        first_name: firstName,
        last_name: lastName,
        email,
        role: 'student',
        phone,
        department,
        is_approved: false
      }]);

    if (insertUserError) {
      console.error('DB Users insert error:', insertUserError);
      throw { stage: 'users_insert', message: insertUserError.message, details: insertUserError.details, hint: insertUserError.hint };
    }

    // 4. Insert into "students" table
    const { error: insertStudentError } = await supabase
      .from('students')
      .insert([{
        id: userId,
        student_document_url: student_doc_url,
        class_level,
        interests,
        available_days,
        status: 'pending'
      }]);

    if (insertStudentError) {
      console.error('DB Students insert error:', insertStudentError);
      throw { stage: 'students_insert', message: insertStudentError.message, details: insertStudentError.details, hint: insertStudentError.hint };
    }

    // 5. Insert into "applications" table
    const { error: insertAppError } = await supabase
      .from('applications')
      .insert([{
        user_id: userId,
        role: 'student',
        document_url: student_doc_url,
        status: 'pending'
      }]);

    if (insertAppError) {
      console.error('DB Applications insert error:', insertAppError);
      throw { stage: 'applications_insert', message: insertAppError.message, details: insertAppError.details, hint: insertAppError.hint };
    }

    res.status(201).json({
      id: userId,
      message: 'Student registered successfully. Your application is pending.'
    });

  } catch (error) {
    console.error("Registration error:", error);

    res.status(500).json({
      message: 'Server error during student registration',
      error: error.message || error,
      details: error.details,
      hint: error.hint,
      stage: error.stage
    });
  }
};

const loginStudent = async (req, res) => {
  const { email, password } = req.body;

  try {
    const authClient = supabase.getAdminClient();
    const { data: authData, error: authError } = await authClient.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      console.error('Login Auth error:', authError);
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const userId = authData.user.id;

    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .eq('role', 'student')
      .maybeSingle();

    if (userError) throw userError;
    if (!user) {
      return res.status(401).json({ message: 'Student profile not found. Please contact admin.' });
    }

    if (user.is_deleted === true) {
      return res.status(401).json({ message: 'Your account has been deleted.' });
    }

    const { data: studentData, error: studentError } = await supabase
      .from('students')
      .select('status')
      .eq('id', userId)
      .maybeSingle();

    if (studentError) throw studentError;
    const status = studentData?.status || 'pending';

    if (status === 'pending') {
      return res.status(403).json({
        message: 'Your application is under review',
        status: 'pending'
      });
    }

    if (status === 'rejected') {
      return res.status(403).json({
        message: 'Your application was rejected',
        status: 'rejected'
      });
    }

    res.json({
      id: user.id,
      name: `${user.first_name} ${user.last_name}`,
      email: user.email,
      role: 'student',
      status: status,
      token: generateToken(user.id)
    });
  } catch (error) {
    console.error('Student login error:', error);
    res.status(500).json({ message: 'Server error during student login' });
  }
};

const calculateAndUpdateMentorBadge = async (mentor_id) => {
  // Fetch all reviews for this mentor
  const { data: reviews, error: reviewsError } = await supabase
    .from('reviews')
    .select('student_id, rating')
    .eq('mentor_id', mentor_id);

  if (reviewsError) {
    throw new Error(`Error fetching reviews: ${reviewsError.message}`);
  }

  // Fetch completed, attended, non-deleted 1-on-1 meetings for this mentor
  const { data: meetings, error: meetingsError } = await supabase
    .from('meetings')
    .select('student_id')
    .eq('mentor_id', mentor_id)
    .eq('meeting_type', '1-on-1')
    .eq('is_deleted', false)
    .eq('attended', true)
    .lt('meeting_date', new Date().toISOString());

  if (meetingsError) {
    throw new Error(`Error fetching meetings: ${meetingsError.message}`);
  }

  // Filter reviews: only include student_id that has at least one completed, attended meeting
  const attendedStudentIds = new Set(meetings.map(m => m.student_id));
  const validReviews = reviews.filter(r => attendedStudentIds.has(r.student_id));

  const totalRatings = validReviews.length;
  let avgRating = 0.0;
  if (totalRatings > 0) {
    const sum = validReviews.reduce((acc, r) => acc + r.rating, 0);
    avgRating = sum / totalRatings;
  }

  // Apply Badge Rules:
  // 🌱 New Mentor: Total ratings < 5
  // ⭐ Trusted Mentor: Total ratings >= 5, average rating between 4.0 and 4.49 (inclusive)
  // 👑 Top Mentor: Total ratings >= 10, average rating >= 4.5
  let badge = '🌱 New Mentor';
  if (totalRatings >= 10 && avgRating >= 4.5) {
    badge = '👑 Top Mentor';
  } else if (totalRatings >= 5 && avgRating >= 4.0) {
    badge = '⭐ Trusted Mentor';
  }

  // Update the badge in the mentors table
  const { error: updateError } = await supabase
    .from('mentors')
    .update({ badge })
    .eq('id', mentor_id);

  if (updateError) {
    throw new Error(`Error updating mentor badge: ${updateError.message}`);
  }

  return { badge, totalRatings, avgRating };
};

const rateMentor = async (req, res) => {
  const { mentor_id, rating, comment } = req.body;

  if (!mentor_id || !rating) {
    return res.status(400).json({ message: "Mentor ID and rating are required." });
  }

  try {
    const student_id = req.user.id;

    // Upsert the review
    const { data, error } = await supabase
      .from('reviews')
      .upsert({
        mentor_id,
        student_id,
        rating,
        comment
      }, { onConflict: 'mentor_id, student_id' });

    if (error) {
      console.error("DB Insert Review Error:", error);
      return res.status(500).json({ message: "Error saving review", error: error.message });
    }

    // Recalculate badge for the mentor
    try {
      const result = await calculateAndUpdateMentorBadge(mentor_id);
      console.log(`Recalculated badge for mentor ${mentor_id}:`, result);
    } catch (calcError) {
      console.error(`Warning: Failed to recalculate mentor badge for ${mentor_id}:`, calcError);
    }

    res.status(200).json({ message: "Review saved successfully." });
  } catch (error) {
    console.error("Rate mentor error:", error);
    res.status(500).json({ message: "Server error during rating mentor" });
  }
};

module.exports = {
  registerStudent,
  loginStudent,
  rateMentor,
  calculateAndUpdateMentorBadge
};
