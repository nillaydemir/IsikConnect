const express = require('express');
const router = express.Router();
const { listPendingApplications, updateApplicationStatus } = require('../controllers/adminController');
const { protect, restrictTo } = require('../middlewares/authMiddleware');

router.get('/applications/pending', protect, restrictTo('admin'), listPendingApplications);
router.post('/applications/update', protect, restrictTo('admin'), updateApplicationStatus);

module.exports = router;
