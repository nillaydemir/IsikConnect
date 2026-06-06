const supabase = require('../config/supabase').getAdminClient();

// Create a new job posting (mentor only)
const createJobPosting = async (req, res) => {
  const { title, company, description, requirements } = req.body;
  const mentorId = req.user.id;

  if (!title || !company || !description || !requirements) {
    return res.status(400).json({ message: 'All fields are required.' });
  }

  try {
    const { data, error } = await supabase
      .from('job_postings')
      .insert({
        mentor_id: mentorId,
        title,
        company,
        description,
        requirements,
        is_deleted: false
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    console.error('Create job posting error:', error);
    res.status(500).json({ message: 'Failed to create job posting.', error: error.message });
  }
};

// Fetch all active job postings
const fetchJobPostings = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('job_postings')
      .select('*, users:mentor_id(first_name, last_name, profile_image_url, is_approved, is_deleted)')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch job postings error:', error);
    res.status(500).json({ message: 'Failed to fetch job postings.', error: error.message });
  }
};

// Fetch job postings created by the current mentor
const fetchMyJobPostings = async (req, res) => {
  const mentorId = req.user.id;
  try {
    const { data, error } = await supabase
      .from('job_postings')
      .select('*, users:mentor_id(first_name, last_name, profile_image_url, is_approved, is_deleted)')
      .eq('mentor_id', mentorId)
      .eq('is_deleted', false)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch my job postings error:', error);
    res.status(500).json({ message: 'Failed to fetch your job postings.', error: error.message });
  }
};

// Update an existing job posting (mentor owner only)
const updateJobPosting = async (req, res) => {
  const { id } = req.params;
  const { title, company, description, requirements } = req.body;
  const mentorId = req.user.id;

  try {
    // Check ownership
    const { data: posting, error: checkError } = await supabase
      .from('job_postings')
      .select('mentor_id')
      .eq('id', id)
      .single();

    if (checkError || !posting) {
      return res.status(404).json({ message: 'Job posting not found.' });
    }

    if (posting.mentor_id !== mentorId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Forbidden: You can only update your own postings.' });
    }

    const { data, error } = await supabase
      .from('job_postings')
      .update({
        title,
        company,
        description,
        requirements,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    res.status(200).json(data);
  } catch (error) {
    console.error('Update job posting error:', error);
    res.status(500).json({ message: 'Failed to update job posting.', error: error.message });
  }
};

// Soft-delete a job posting (mentor owner only)
const deleteJobPosting = async (req, res) => {
  const { id } = req.params;
  const mentorId = req.user.id;

  try {
    // Check ownership
    const { data: posting, error: checkError } = await supabase
      .from('job_postings')
      .select('mentor_id')
      .eq('id', id)
      .single();

    if (checkError || !posting) {
      return res.status(404).json({ message: 'Job posting not found.' });
    }

    if (posting.mentor_id !== mentorId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Forbidden: You can only delete your own postings.' });
    }

    const { error } = await supabase
      .from('job_postings')
      .update({ is_deleted: true })
      .eq('id', id);

    if (error) throw error;
    res.status(200).json({ message: 'Job posting deleted successfully.' });
  } catch (error) {
    console.error('Delete job posting error:', error);
    res.status(500).json({ message: 'Failed to delete job posting.', error: error.message });
  }
};

// Upload CV document to Supabase Storage (student only)
const uploadCV = async (req, res) => {
  const file = req.file;
  const studentId = req.user.id;

  if (!file) {
    return res.status(400).json({ message: 'No file uploaded.' });
  }

  try {
    const BUCKET_NAME = 'documents';
    const fileName = `cv_${studentId}_${Date.now()}_${file.originalname.replace(/\s+/g, '_')}`;

    const { data, error: uploadError } = await supabase.storage
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

    res.status(200).json({ cvUrl: publicUrl });
  } catch (error) {
    console.error('Upload CV error:', error);
    res.status(500).json({ message: 'Failed to upload CV.', error: error.message });
  }
};

// Apply for a job posting (student only)
const applyForJob = async (req, res) => {
  const { jobId } = req.params;
  const { cover_note, cv_url } = req.body;
  const studentId = req.user.id;

  try {
    const { data, error } = await supabase
      .from('job_applications')
      .insert({
        job_id: jobId,
        student_id: studentId,
        cover_note: cover_note || null,
        cv_url: cv_url || null,
        status: 'applied'
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    console.error('Apply for job error:', error);
    res.status(500).json({ message: 'Failed to apply for job.', error: error.message });
  }
};

// Fetch applications for a specific job posting (mentor owner only)
const fetchApplicationsForJob = async (req, res) => {
  const { jobId } = req.params;
  const mentorId = req.user.id;

  try {
    // Verify mentor owns the job posting
    const { data: posting, error: checkError } = await supabase
      .from('job_postings')
      .select('mentor_id')
      .eq('id', jobId)
      .single();

    if (checkError || !posting) {
      return res.status(404).json({ message: 'Job posting not found.' });
    }

    if (posting.mentor_id !== mentorId) {
      return res.status(403).json({ message: 'Forbidden: You can only view applications for your own postings.' });
    }

    const { data, error } = await supabase
      .from('job_applications')
      .select('*, students:student_id(class_level, student_document_url, users:users!students_id_fkey(first_name, last_name, email, department))')
      .eq('job_id', jobId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch applications for job error:', error);
    res.status(500).json({ message: 'Failed to fetch applications.', error: error.message });
  }
};

// Fetch applications made by the current student (student only)
const fetchMyApplications = async (req, res) => {
  const studentId = req.user.id;

  try {
    const { data, error } = await supabase
      .from('job_applications')
      .select('*, job_postings(*, users:mentor_id(first_name, last_name))')
      .eq('student_id', studentId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch my applications error:', error);
    res.status(500).json({ message: 'Failed to fetch your applications.', error: error.message });
  }
};

// Check application status for a specific job (student only)
const checkMyApplicationStatus = async (req, res) => {
  const { jobId } = req.params;
  const studentId = req.user.id;

  try {
    const { data, error } = await supabase
      .from('job_applications')
      .select('*, students:student_id(class_level, student_document_url, users:users!students_id_fkey(first_name, last_name, email, department))')
      .eq('job_id', jobId)
      .eq('student_id', studentId)
      .maybeSingle();

    if (error) throw error;
    res.status(200).json(data || null);
  } catch (error) {
    console.error('Check application status error:', error);
    res.status(500).json({ message: 'Failed to check application status.', error: error.message });
  }
};

// Update application status (Accept / Reject) with feedback (mentor owner only)
const updateApplicationStatus = async (req, res) => {
  const { applicationId } = req.params;
  const { status, feedback } = req.body;
  const mentorId = req.user.id;

  if (!status || !['accepted', 'rejected'].includes(status)) {
    return res.status(400).json({ message: 'Invalid status. Must be accepted or rejected.' });
  }

  try {
    // Verify that the logged-in mentor owns the job posting associated with this application
    const { data: application, error: appError } = await supabase
      .from('job_applications')
      .select('job_id, job_postings(mentor_id)')
      .eq('id', applicationId)
      .single();

    if (appError || !application) {
      return res.status(404).json({ message: 'Job application not found.' });
    }

    if (application.job_postings.mentor_id !== mentorId) {
      return res.status(403).json({ message: 'Forbidden: You can only update applications for your own postings.' });
    }

    const { data, error } = await supabase
      .from('job_applications')
      .update({
        status,
        feedback: feedback || null,
        updated_at: new Date().toISOString()
      })
      .eq('id', applicationId)
      .select()
      .single();

    if (error) throw error;
    res.status(200).json(data);
  } catch (error) {
    console.error('Update application status error:', error);
    res.status(500).json({ message: 'Failed to update application status.', error: error.message });
  }
};

module.exports = {
  createJobPosting,
  fetchJobPostings,
  fetchMyJobPostings,
  updateJobPosting,
  deleteJobPosting,
  uploadCV,
  applyForJob,
  fetchApplicationsForJob,
  fetchMyApplications,
  checkMyApplicationStatus,
  updateApplicationStatus
};
