const express = require('express');

const { createReview, venueReviews } = require('../controllers/reviewController');
const { protect, requireRoles } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/', protect, requireRoles('CUSTOMER'), createReview);
router.get('/venue/:venueId', venueReviews);

module.exports = router;
