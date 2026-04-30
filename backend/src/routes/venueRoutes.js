const express = require('express');

const {
  createVenue,
  deleteVenue,
  getVenue,
  listVenues,
  myHostVenues,
  searchVenues,
  updateVenue
} = require('../controllers/venueController');
const { protect, requireRoles } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', listVenues);
router.get('/search', searchVenues);
router.get('/host/my', protect, requireRoles('HOST'), myHostVenues);
router.get('/:id', getVenue);
router.post('/', protect, requireRoles('HOST', 'VENUEHUB_ADMIN'), createVenue);
router.put('/:id', protect, requireRoles('HOST', 'VENUEHUB_ADMIN'), updateVenue);
router.delete('/:id', protect, requireRoles('HOST', 'VENUEHUB_ADMIN'), deleteVenue);

module.exports = router;
