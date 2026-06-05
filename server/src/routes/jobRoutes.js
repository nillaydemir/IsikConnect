const express = require('express');
const multer = require('multer');
const router = express.Router();

const {
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
} = require('../controllers/jobController');

const { protect, restrictTo } = require('../middlewares/authMiddleware');

const upload = multer({ storage: multer.memoryStorage() });

router.get('/', protect, fetchJobPostings);
router.get('/my-postings', protect, restrictTo('mentor'), fetchMyJobPostings);
router.post('/', protect, restrictTo('mentor'), createJobPosting);
router.put('/:id', protect, restrictTo('mentor'), updateJobPosting);
router.delete('/:id', protect, restrictTo('mentor'), deleteJobPosting);

router.post('/upload-cv', protect, restrictTo('student'), upload.single('cv'), uploadCV);
router.post('/:jobId/apply', protect, restrictTo('student'), applyForJob);
router.get('/:jobId/applications', protect, restrictTo('mentor'), fetchApplicationsForJob);
router.get('/my-applications', protect, restrictTo('student'), fetchMyApplications);
router.get('/:jobId/application-status', protect, restrictTo('student'), checkMyApplicationStatus);
router.post('/applications/:applicationId/status', protect, restrictTo('mentor'), updateApplicationStatus);

module.exports = router;
