const supabase = require('../config/supabase').getAdminClient();

/**
 * Update user profile information (name, phone, department, bio)
 */
const updateProfile = async (req, res) => {
  const { userId } = req.params;
  const { firstName, lastName, phone, department, bio, company, jobTitle, availableDays, interests, maxStudents } = req.body;
  
  // Authorization check
  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: You can only update your own profile.' });
  }

  try {
    // 1. Get user role first
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('role')
      .eq('id', userId)
      .single();

    if (userError) throw userError;

    // 2. Update core users table
    const { error: coreError } = await supabase
      .from('users')
      .update({
        first_name: firstName,
        last_name: lastName,
        phone,
        department,
        bio
      })
      .eq('id', userId);

    if (coreError) throw coreError;

    // 3. Update role-specific table
    if (user.role === 'mentor') {
      const { error: mentorError } = await supabase
        .from('mentors')
        .update({
          company,
          job_title: jobTitle,
          available_days: availableDays,
          interests,
          max_students: maxStudents !== undefined ? maxStudents : 1
        })
        .eq('id', userId);
      if (mentorError) throw mentorError;
    } else if (user.role === 'student') {
      const { error: studentError } = await supabase
        .from('students')
        .update({
          available_days: availableDays,
          interests
        })
        .eq('id', userId);
      if (studentError) throw studentError;
    }

    // 4. Return updated full user profile
    const { data: finalUser, error: finalError } = await supabase
      .from('users')
      .select('*, mentors(*), students(*)')
      .eq('id', userId)
      .single();

    if (finalError) throw finalError;

    // Merge role specific data
    const mergedData = { ...finalUser };
    if (finalUser.role === 'student' && finalUser.students) {
      const s = finalUser.students;
      if (Array.isArray(s) && s.length > 0) {
        Object.assign(mergedData, s[0]);
      } else if (s && typeof s === 'object') {
        Object.assign(mergedData, s);
      }
    } else if (finalUser.role === 'mentor' && finalUser.mentors) {
      const m = finalUser.mentors;
      if (Array.isArray(m) && m.length > 0) {
        Object.assign(mergedData, m[0]);
      } else if (m && typeof m === 'object') {
        Object.assign(mergedData, m);
      }
    }

    res.json({ message: 'Profile updated successfully', user: mergedData });
  } catch (error) {
    console.error('Update Profile Error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Upload profile image to Supabase Storage and update user record
 */
const uploadProfileImage = async (req, res) => {
  const { userId } = req.params;
  const file = req.file;

  // Authorization check
  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: You can only update your own profile image.' });
  }

  if (!file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  try {
    const BUCKET_NAME = 'profile-images';
    const fileName = `${userId}_${Date.now()}.png`;

    const { data: uploadData, error: uploadError } = await supabase.storage
      .from(BUCKET_NAME)
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: true
      });

    if (uploadError) throw uploadError;

    // Get Public URL
    const { data: { publicUrl } } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(fileName);

    // Update user record
    const { error: updateError } = await supabase
      .from('users')
      .update({ profile_image_url: publicUrl })
      .eq('id', userId);

    if (updateError) throw updateError;

    res.json({ message: 'Profile image uploaded', profileImageUrl: publicUrl });
  } catch (error) {
    console.error('Upload Profile Image Error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Get user by ID (merging basic users with mentors or students tables)
 */
const fetchUserById = async (req, res) => {
  const { userId } = req.params;
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*, mentors(*), students(*)')
      .eq('id', userId)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const mergedData = { ...data };
    if (data.role === 'student' && data.students) {
      const s = data.students;
      if (Array.isArray(s) && s.length > 0) {
        Object.assign(mergedData, s[0]);
      } else if (s && typeof s === 'object') {
        Object.assign(mergedData, s);
      }
    } else if (data.role === 'mentor' && data.mentors) {
      const m = data.mentors;
      if (Array.isArray(m) && m.length > 0) {
        Object.assign(mergedData, m[0]);
      } else if (m && typeof m === 'object') {
        Object.assign(mergedData, m);
      }
    }

    res.status(200).json(mergedData);
  } catch (error) {
    console.error('Fetch user by ID error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Get all departments with their configured interests list
 */
const fetchDepartments = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('departments')
      .select('name, interests(name)');

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch departments error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Get feedback reviews for a specific mentor
 */
const fetchMentorReviews = async (req, res) => {
  const { userId } = req.params;
  try {
    const { data, error } = await supabase
      .from('reviews')
      .select('*, students(users(first_name, last_name, profile_image_url))')
      .eq('mentor_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch mentor reviews error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Delete profile image (setting to null in database)
 */
const deleteProfileImage = async (req, res) => {
  const { userId } = req.params;

  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: You can only delete your own profile image.' });
  }

  try {
    const { error } = await supabase
      .from('users')
      .update({ profile_image_url: null })
      .eq('id', userId);

    if (error) throw error;
    res.status(200).json({ message: 'Profile image deleted successfully.' });
  } catch (error) {
    console.error('Delete profile image error:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Fetch last login datetime (admins only)
 */
const fetchLastLogin = async (req, res) => {
  const { userId } = req.params;

  if (req.user.role !== 'admin' && req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden: Access denied.' });
  }

  try {
    const { data, error } = await supabase
      .from('user_logins')
      .select('last_sign_in_at')
      .eq('id', userId)
      .maybeSingle();

    if (error) throw error;
    res.status(200).json(data || { last_sign_in_at: null });
  } catch (error) {
    console.error('Fetch last login error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  updateProfile,
  uploadProfileImage,
  fetchUserById,
  fetchDepartments,
  fetchMentorReviews,
  deleteProfileImage,
  fetchLastLogin
};
