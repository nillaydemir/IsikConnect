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
      email_confirm: true
    });

    if (authError) {
      console.error('Supabase Auth error:', authError);
      return res.status(400).json({ message: authError.message });
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
        department,
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
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
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

module.exports = {
  registerStudent,
  loginStudent
};
