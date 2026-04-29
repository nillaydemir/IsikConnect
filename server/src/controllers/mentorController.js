const supabase = require('../config/supabase');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const BUCKET_NAME = 'mentor-docs';

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
};

const registerMentor = async (req, res) => {
  console.log('--- [DEBUG] Registering Mentor Request ---');
  console.log('Headers:', req.headers);
  console.log('Body Fields:', Object.keys(req.body));
  
  if (req.file) {
    console.log('File detected:', {
      fieldname: req.file.fieldname,
      originalname: req.file.originalname,
      size: req.file.size
    });
  } else {
    console.log('CRITICAL: No file detected in req.file');
  }
  
  let { full_name, email, password, department, graduation_year, company, job_title, max_students, interests, phone, available_days } = req.body;
 
  // Handle JSON strings from multipart form-data (CRITICAL for Supabase Array types)
  try {
    if (typeof available_days === 'string') available_days = JSON.parse(available_days);
    if (typeof interests === 'string') interests = JSON.parse(interests);
  } catch (e) {
    console.warn('Failed to parse JSON fields:', e);
    // If parsing fails, ensure they are at least empty arrays if null
    available_days = available_days || [];
    interests = interests || [];
  }

  // Descriptive Validation
  if (!email) return res.status(400).json({ message: "Email is missing" });
  if (!password) return res.status(400).json({ message: "Password is missing" });
  if (!full_name) return res.status(400).json({ message: "Full name is missing" });
  if (!req.file) {
    return res.status(400).json({
      message: "Graduation document (file) was not received by the server. Please check the file selection."
    });
  }

  try {
    let graduation_doc_url = '';
    
    // 1. File upload to Supabase Storage
    const file = req.file;
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
      throw { stage: 'file_upload', error: uploadError };
    }

    const { data: publicUrlData } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(uploadData.path);
    
    graduation_doc_url = publicUrlData.publicUrl;

    // 2. Create user in Supabase Auth using Admin API (auto-confirms email)
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    if (authError) {
      console.error('Supabase Auth error:', authError);
      return res.status(400).json({ message: authError.message });
    }

    const userId = authData.user.id;

    // First and last name extraction 
    const nameParts = full_name.trim().split(' ');
    const firstName = nameParts[0];
    const lastName = nameParts.slice(1).join(' ') || '';

    // 3. Insert into custom "users" table
    const { error: insertUserError } = await supabase.from('users').insert([{ 
        id: userId,
        first_name: firstName,
        last_name: lastName,
        email,
        role: 'mentor',
        phone,
        department,
        is_approved: false
       }]);
    if (insertUserError) {
      console.error('DB Users insert error:', insertUserError);
      throw { stage: 'users_insert', error: insertUserError };
    }

    // 4. Insert into "mentors" table
    const { error: insertMentorError } = await supabase.from('mentors').insert([{ 
        id: userId,
        graduation_document_url: graduation_doc_url,
        company,
        job_title,
        graduation_year,
        max_students,
        interests,
        available_days,
        status: 'pending'
       }]);
    if (insertMentorError) {
      console.error('DB Mentors insert error:', insertMentorError);
      throw { stage: 'mentors_insert', error: insertMentorError };
    }

    // 5. Insert into "applications" table
    const { error: insertAppError } = await supabase.from('applications').insert([{ 
        user_id: userId,
        role: 'mentor',
        document_url: graduation_doc_url,
        status: 'pending'
       }]);
    if (insertAppError) {
      console.error('DB Applications insert error:', insertAppError);
      throw { stage: 'applications_insert', error: insertAppError };
    }

    res.status(201).json({
      id: userId,
      full_name: full_name,
      email: email,
      status: 'pending',
      message: 'Mentor registered successfully. Your application is under review.'
    });

  } catch (error) {
    console.error("Registration error:", error);
    res.status(500).json({ 
      message: 'Server error during mentor registration',
      error: error.message || error,
      details: error.details,
      hint: error.hint,
      stage: error.stage
    });
  }
};

const loginMentor = async (req, res) => {
  const { email, password } = req.body;

  try {
    // 1. Authenticate with Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      console.error('Login Auth error:', authError);
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const userId = authData.user.id;

    // 2. Fetch user from custom "users" table
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .eq('role', 'mentor')
      .maybeSingle();

    if (userError) throw userError;
    if (!user) {
      return res.status(401).json({ message: 'Mentor profile not found. Please contact admin.' });
    }

    // 3. Check status in "mentors" table
    const { data: mentor, error: mentorError } = await supabase
      .from('mentors')
      .select('status')
      .eq('id', userId)
      .maybeSingle();

    if (mentorError) throw mentorError;
    const status = mentor?.status || 'pending';

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
      role: 'mentor',
      status: status,
      token: generateToken(user.id)
    });
  } catch (error) {
    console.error('Mentor login error:', error);
    res.status(500).json({ message: 'Server error during mentor login' });
  }
};

const uploadDoc = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const file = req.file;
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    const fileName = `${Date.now()}_${sanitizedName}`;
    const { data, error } = await supabase.storage
      .from(BUCKET_NAME)
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: false
      });

    if (error) {
      throw error;
    }

    const { data: publicUrlData } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(data.path);

    res.json({ url: publicUrlData.publicUrl });
  } catch (error) {
    console.error('File upload error:', error);
    res.status(500).json({ message: 'Error uploading document' });
  }
};

module.exports = {
  registerMentor,
  loginMentor,
  uploadDoc
};
