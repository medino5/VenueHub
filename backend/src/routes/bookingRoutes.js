const express = require('express');

const {
  createBooking,
  hostBookings,
  hostIncomeSummary,
  myBookings,
  updateBookingStatus,
  venueUnavailableDates
} = require('../controllers/bookingController');
const { protect, requireRoles } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/', protect, requireRoles('CUSTOMER'), createBooking);
router.get('/my', protect, requireRoles('CUSTOMER'), myBookings);
router.get('/host', protect, requireRoles('HOST'), hostBookings);
router.get('/host/income', protect, requireRoles('HOST'), hostIncomeSummary);
router.get('/venue/:venueId/unavailable-dates', protect, venueUnavailableDates);
router.put('/:id/status', protect, requireRoles('HOST', 'VENUEHUB_ADMIN'), updateBookingStatus);

module.exports = router;
