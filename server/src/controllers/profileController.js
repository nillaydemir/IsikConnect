const supabase = require('../config/supabase');

/**
 * Update user profile information (name, phone, department, bio)
 */
const updateProfile = async (req, res) => {
  const { userId } = req.params;
  const { firstName, lastName, phone, department, bio, company, jobTitle, availableDays } = req.body;

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
          available_days: availableDays
        })
        .eq('user_id', userId);
      if (mentorError) throw mentorError;
    } else if (user.role === 'student') {
      const { error: studentError } = await supabase
        .from('students')
        .update({
          available_days: availableDays
        })
        .eq('user_id', userId);
      if (studentError) throw studentError;
    }

    // 4. Return updated full user profile
    const { data: finalUser, error: finalError } = await supabase
      .from('users')
      .select('*, mentors(*), students(*)')
      .eq('id', userId)
      .single();

    if (finalError) throw finalError;

    res.json({ message: 'Profile updated successfully', user: finalUser });
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

module.exports = {
  updateProfile,
  uploadProfileImage
};
