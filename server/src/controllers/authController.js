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

    // Mark all existing forum posts as read for the new user
    try {
      const { data: allPosts, error: postsError } = await supabase
        .from('forum_posts')
        .select('id');

      if (postsError) {
        console.warn('Warning: Could not fetch forum posts to mark as read:', postsError.message);
      } else if (allPosts && allPosts.length > 0) {
        const readPostsData = allPosts.map(post => ({
          post_id: post.id,
          user_id: newUser.id
        }));

        const { error: upsertError } = await supabase
          .from('forum_read_posts')
          .insert(readPostsData);

        if (upsertError) {
          console.warn('Warning: Could not mark existing posts as read:', upsertError.message);
        }
      }
    } catch (err) {
      console.warn('Warning: Error marking forum posts as read:', err.message);
    }

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

    let user;
    let userId;
    let authSuccess = false;

    // 1. Try to authenticate with Supabase Auth
    try {
      console.log(`--- [DEBUG] loginUnified: Attempting Supabase Auth for ${email} ---`);
      const authClient = supabase.getAdminClient();
      const { data: authData, error: authError } = await authClient.auth.signInWithPassword({
        email,
        password,
      });

      if (!authError && authData && authData.user) {
        userId = authData.user.id;
        authSuccess = true;
        console.log(`[DEBUG] Supabase Auth successful for ${email}, userId: ${userId}`);
      } else {
        console.warn(`[DEBUG] Supabase Auth failed for ${email}. Error:`, authError ? authError.message : 'No user returned');
        console.log('Trying local DB fallback...');
      }
    } catch (err) {
      console.error('[DEBUG] Supabase Auth connection error:', err);
      console.log('Trying local DB fallback...');
    }

    // 2. Local DB Fallback (e.g. for pre-seeded admin user who doesn't have a Supabase Auth account)
    if (authSuccess && userId) {
      const { data, error: userError } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (userError) throw userError;
      user = data;
    } else {
      // Look up user by email directly in custom "users" table
      const { data, error: userError } = await supabase
        .from('users')
        .select('*')
        .eq('email', email)
        .maybeSingle();

      if (userError) throw userError;
      
      if (data && data.password) {
        let isMatch = false;
        if (data.password.startsWith('$2b$') || data.password.startsWith('$2a$')) {
          isMatch = await bcrypt.compare(password, data.password);
        } else {
          isMatch = (password === data.password);
        }

        if (isMatch) {
          user = data;
          userId = data.id;
        }
      }
    }

    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
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
        is_approved: mergedUser.is_approved,
        created_at: mergedUser.created_at,
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

