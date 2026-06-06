const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const supabase = require('../config/supabase');

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
};

const register = async (req, res) => {
  const { name, email, password } = req.body;

  try {
    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Please provide all required fields' });
    }

    const { data: existingUser, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .maybeSingle();

    if (fetchError) throw fetchError;
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const { data: newUser, error: insertError } = await supabase
      .from('users')
      .insert([{ name, email, password: hashedPassword }])
      .select()
      .single();

    if (insertError) throw insertError;

    res.status(201).json({
      id: newUser.id,
      name: newUser.name,
      email: newUser.email,
      token: generateToken(newUser.id)
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error during registration' });
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ message: 'Please provide email and password' });
    }

    const { data: user, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .maybeSingle();

    if (fetchError) throw fetchError;
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    let isMatch = false;
    if (user.password) {
      if (user.password.startsWith('$2b$') || user.password.startsWith('$2a$')) {
        isMatch = await bcrypt.compare(password, user.password);
      } else {
        isMatch = (password === user.password);
      }
    }

    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      token: generateToken(user.id)
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
};

const loginUnified = async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ message: 'Please provide email and password' });
    }

    // 1. Authenticate with Supabase Auth
    const authClient = supabase.getAdminClient();
    const { data: authData, error: authError } = await authClient.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      console.error('Unified Login Auth error:', authError);
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const userId = authData.user.id;

    // 2. Fetch user details from custom "users" table
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (userError) throw userError;
    if (!user) {
      return res.status(401).json({ message: 'User profile not found. Please contact admin.' });
    }

    if (user.is_deleted === true) {
      return res.status(401).json({ message: 'Your account has been deactivated. Please contact support.' });
    }

    let status = 'approved';
    const mergedUser = { ...user };

    // 3. Handle role-specific checks & joins
    if (user.role === 'mentor') {
      const { data: mentor, error: mentorError } = await supabase
        .from('mentors')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (mentorError) throw mentorError;
      status = mentor?.status || 'pending';

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

      if (mentor) {
        Object.assign(mergedUser, mentor);
      }
    } else if (user.role === 'student') {
      const { data: student, error: studentError } = await supabase
        .from('students')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (studentError) throw studentError;
      status = student?.status || 'pending';

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

      if (student) {
        Object.assign(mergedUser, student);
      }
    }

    // 4. Return token & merged user profile
    res.json({
      token: generateToken(user.id),
      user: {
        id: mergedUser.id,
        first_name: mergedUser.first_name,
        last_name: mergedUser.last_name,
        email: mergedUser.email,
        role: mergedUser.role,
        profile_image_url: mergedUser.profile_image_url,
        phone: mergedUser.phone,
        department: mergedUser.department,
        bio: mergedUser.bio,
        is_deleted: mergedUser.is_deleted,
        // Mentor specific fields
        company: mergedUser.company,
        job_title: mergedUser.job_title,
        graduation_year: mergedUser.graduation_year,
        max_students: mergedUser.max_students,
        available_days: mergedUser.available_days || [],
        interests: mergedUser.interests || [],
        badge: mergedUser.badge || '🌱 New Mentor',
        // Student specific fields
        class_level: mergedUser.class_level,
      },
      status: status
    });
  } catch (error) {
    console.error('Unified login error:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
};

module.exports = {
  register,
  login,
  loginUnified
};

