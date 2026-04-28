const express = require('express');
const router = express.Router();
const { listPendingApplications, updateApplicationStatus } = require('../controllers/adminController');

router.get('/applications/pending', listPendingApplications);
router.post('/applications/update', updateApplicationStatus);

module.exports = router;
