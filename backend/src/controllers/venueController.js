const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');

const venueInclude = {
  host: { select: { id: true, name: true, email: true, phone: true } },
  images: { orderBy: { sortOrder: 'asc' } },
  amenities: true,
  facilities: true,
  reviews: {
    include: { customer: { select: { id: true, name: true, profileImageUrl: true } } },
    orderBy: { createdAt: 'desc' }
  }
};

const formatVenue = (venue) => {
  const reviews = venue.reviews || [];
  const rating =
    reviews.length === 0
      ? 0
      : Number((reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length).toFixed(1));

  return {
    ...venue,
    pricePerDay: Number(venue.pricePerDay),
    averageRating: rating,
    reviewCount: reviews.length
  };
};

const listVenues = asyncHandler(async (_req, res) => {
  const venues = await prisma.venue.findMany({
    where: { status: 'APPROVED' },
    include: venueInclude,
    orderBy: { createdAt: 'desc' }
  });

  res.json({ venues: venues.map(formatVenue) });
});

const searchVenues = asyncHandler(async (req, res) => {
  const { query, location } = req.query;
  const venues = await prisma.venue.findMany({
    where: {
      status: 'APPROVED',
      ...(query && {
        name: { contains: String(query), mode: 'insensitive' }
      }),
      ...(location && {
        location: { contains: String(location), mode: 'insensitive' }
      })
    },
    include: venueInclude,
    orderBy: { createdAt: 'desc' }
  });

  res.json({ venues: venues.map(formatVenue) });
});

const myHostVenues = asyncHandler(async (req, res) => {
  const venues = await prisma.venue.findMany({
    where: { hostId: req.user.id },
    include: venueInclude,
    orderBy: { createdAt: 'desc' }
  });

  res.json({ venues: venues.map(formatVenue) });
});

const getVenue = asyncHandler(async (req, res) => {
  const venue = await prisma.venue.findUnique({
    where: { id: req.params.id },
    include: venueInclude
  });

  if (!venue || venue.status !== 'APPROVED') {
    throw new ApiError(404, 'Venue not found.');
  }

  res.json({ venue: formatVenue(venue) });
});

const createVenue = asyncHandler(async (req, res) => {
  const { name, description, pricePerDay, capacity, location, address, images = [], amenities = [], facilities = [] } =
    req.body;

  if (!name || !description || !pricePerDay || !capacity || !location || !address) {
    throw new ApiError(400, 'Name, description, price, capacity, location, and address are required.');
  }

  const venue = await prisma.venue.create({
    data: {
      hostId: req.user.id,
      name,
      description,
      pricePerDay: Number(pricePerDay),
      capacity: Number(capacity),
      location,
      address,
      status: req.user.role === 'VENUEHUB_ADMIN' ? 'APPROVED' : 'PENDING',
      images: {
        create: images.map((imageUrl, index) =>
          typeof imageUrl === 'string'
            ? { imageUrl, sortOrder: index }
            : { imageUrl: imageUrl.imageUrl, caption: imageUrl.caption, publicId: imageUrl.publicId, sortOrder: index }
        )
      },
      amenities: { create: amenities.map((name) => ({ name })) },
      facilities: { create: facilities.map((name) => ({ name })) }
    },
    include: venueInclude
  });

  res.status(201).json({ venue: formatVenue(venue) });
});

const updateVenue = asyncHandler(async (req, res) => {
  const existingVenue = await prisma.venue.findUnique({ where: { id: req.params.id } });
  if (!existingVenue) {
    throw new ApiError(404, 'Venue not found.');
  }

  if (req.user.role !== 'VENUEHUB_ADMIN' && existingVenue.hostId !== req.user.id) {
    throw new ApiError(403, 'You can only edit your own venues.');
  }

  const { images, amenities, facilities, ...venueData } = req.body;
  const data = {
    ...(venueData.name && { name: venueData.name }),
    ...(venueData.description && { description: venueData.description }),
    ...(venueData.pricePerDay && { pricePerDay: Number(venueData.pricePerDay) }),
    ...(venueData.capacity && { capacity: Number(venueData.capacity) }),
    ...(venueData.location && { location: venueData.location }),
    ...(venueData.address && { address: venueData.address }),
    ...(req.user.role === 'VENUEHUB_ADMIN' && venueData.status && { status: String(venueData.status).toUpperCase() })
  };

  await prisma.$transaction(async (tx) => {
    await tx.venue.update({ where: { id: req.params.id }, data });

    if (Array.isArray(images)) {
      await tx.venueImage.deleteMany({ where: { venueId: req.params.id } });
      if (images.length > 0) {
        await tx.venueImage.createMany({
          data: images.map((imageUrl, index) =>
            typeof imageUrl === 'string'
              ? { venueId: req.params.id, imageUrl, sortOrder: index }
              : {
                  venueId: req.params.id,
                  imageUrl: imageUrl.imageUrl,
                  caption: imageUrl.caption,
                  publicId: imageUrl.publicId,
                  sortOrder: index
                }
          )
        });
      }
    }

    if (Array.isArray(amenities)) {
      await tx.amenity.deleteMany({ where: { venueId: req.params.id } });
      if (amenities.length > 0) {
        await tx.amenity.createMany({ data: amenities.map((name) => ({ venueId: req.params.id, name })) });
      }
    }

    if (Array.isArray(facilities)) {
      await tx.facility.deleteMany({ where: { venueId: req.params.id } });
      if (facilities.length > 0) {
        await tx.facility.createMany({ data: facilities.map((name) => ({ venueId: req.params.id, name })) });
      }
    }
  });

  const venue = await prisma.venue.findUnique({ where: { id: req.params.id }, include: venueInclude });
  res.json({ venue: formatVenue(venue) });
});

const deleteVenue = asyncHandler(async (req, res) => {
  const venue = await prisma.venue.findUnique({ where: { id: req.params.id } });
  if (!venue) {
    throw new ApiError(404, 'Venue not found.');
  }

  if (req.user.role !== 'VENUEHUB_ADMIN' && venue.hostId !== req.user.id) {
    throw new ApiError(403, 'You can only delete your own venues.');
  }

  await prisma.venue.delete({ where: { id: req.params.id } });
  res.json({ message: 'Venue deleted successfully.' });
});

module.exports = {
  createVenue,
  deleteVenue,
  getVenue,
  listVenues,
  myHostVenues,
  searchVenues,
  updateVenue
};
