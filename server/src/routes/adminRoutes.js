const express = require('express');
const router = express.Router();
const { listPendingMentors, approveMentor } = require('../controllers/adminController');

router.get('/mentors', listPendingMentors);
router.post('/mentor/approve', approveMentor);

module.exports = router;
