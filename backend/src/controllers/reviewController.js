const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');

const createReview = asyncHandler(async (req, res) => {
  const { bookingId, rating, comment } = req.body;
  const parsedRating = Number(rating);

  if (!bookingId || !parsedRating || parsedRating < 1 || parsedRating > 5) {
    throw new ApiError(400, 'Booking and rating from 1 to 5 are required.');
  }

  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking) {
    throw new ApiError(404, 'Booking not found.');
  }

  if (booking.customerId !== req.user.id) {
    throw new ApiError(403, 'You can only review your own completed bookings.');
  }

  if (booking.status !== 'COMPLETED') {
    throw new ApiError(400, 'Reviews are only allowed after completed bookings.');
  }

  const review = await prisma.review.create({
    data: {
      bookingId,
      venueId: booking.venueId,
      customerId: req.user.id,
      rating: parsedRating,
      comment
    },
    include: { customer: { select: { id: true, name: true, profileImageUrl: true } } }
  });

  res.status(201).json({ review });
});

const venueReviews = asyncHandler(async (req, res) => {
  const reviews = await prisma.review.findMany({
    where: { venueId: req.params.venueId },
    include: { customer: { select: { id: true, name: true, profileImageUrl: true } } },
    orderBy: { createdAt: 'desc' }
  });

  res.json({ reviews });
});

module.exports = {
  createReview,
  venueReviews
};
