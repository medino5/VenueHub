const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { publicUser, toNumber } = require('../utils/formatters');
const { formatBooking } = require('./bookingController');

const startOfWindow = (days) => {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date;
};

const sumServiceFees = (bookings) =>
  Number(bookings.reduce((sum, booking) => sum + toNumber(booking.serviceFee), 0).toFixed(2));

const getPlatformSetting = () =>
  prisma.platformSetting.upsert({
    where: { id: 'platform' },
    update: {},
    create: { id: 'platform', serviceFeePercent: 10 }
  });

const dashboard = asyncHandler(async (_req, res) => {
  const [totalUsers, totalHosts, totalVenues, pendingVenues, totalBookings, pendingBookings, completedBookings, paidBookings, setting] = await Promise.all([
    prisma.user.count(),
    prisma.user.count({ where: { role: 'HOST' } }),
    prisma.venue.count(),
    prisma.venue.count({ where: { status: 'PENDING' } }),
    prisma.booking.count(),
    prisma.booking.count({ where: { status: 'PENDING' } }),
    prisma.booking.count({ where: { status: 'COMPLETED' } }),
    prisma.booking.findMany({ where: { paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] } } }),
    getPlatformSetting()
  ]);

  res.json({
    dashboard: {
      totalUsers,
      totalHosts,
      totalVenues,
      pendingVenues,
      totalBookings,
      pendingBookings,
      completedBookings,
      platformIncome: sumServiceFees(paidBookings),
      serviceFeePercent: toNumber(setting.serviceFeePercent)
    }
  });
});

const users = asyncHandler(async (_req, res) => {
  const allUsers = await prisma.user.findMany({
    include: { bookings: true, venues: true },
    orderBy: { createdAt: 'desc' }
  });
  res.json({ users: allUsers.map(publicUser) });
});

const hosts = asyncHandler(async (_req, res) => {
  const hostUsers = await prisma.user.findMany({
    where: { role: 'HOST' },
    include: { venues: true },
    orderBy: { createdAt: 'desc' }
  });

  res.json({
    hosts: hostUsers.map((host) => ({
      ...publicUser(host),
      venues: host.venues.map((venue) => ({ ...venue, pricePerDay: toNumber(venue.pricePerDay) }))
    }))
  });
});

const venues = asyncHandler(async (_req, res) => {
  const allVenues = await prisma.venue.findMany({
    include: {
      host: { select: { id: true, name: true, email: true } },
      images: true,
      amenities: true,
      facilities: true
    },
    orderBy: { createdAt: 'desc' }
  });

  res.json({
    venues: allVenues.map((venue) => ({ ...venue, pricePerDay: toNumber(venue.pricePerDay) }))
  });
});

const bookings = asyncHandler(async (_req, res) => {
  const allBookings = await prisma.booking.findMany({
    include: {
      customer: { select: { id: true, name: true, email: true, phone: true } },
      venue: { include: { host: { select: { id: true, name: true, email: true } }, images: true } },
      payments: true,
      receipt: true,
      review: true
    },
    orderBy: { createdAt: 'desc' }
  });

  res.json({ bookings: allBookings.map(formatBooking) });
});

const incomeSummary = asyncHandler(async (_req, res) => {
  const paidWhere = { paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] } };
  const [weekly, monthly, annual, allTime, completedBookings, setting] = await Promise.all([
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(7) } }, include: { payments: true, venue: true } }),
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(30) } }, include: { payments: true, venue: true } }),
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(365) } }, include: { payments: true, venue: true } }),
    prisma.booking.findMany({ where: paidWhere, include: { payments: true, venue: true } }),
    prisma.booking.count({ where: { status: 'COMPLETED' } }),
    getPlatformSetting()
  ]);

  const grossPaid = (bookings) =>
    Number(
      bookings
        .reduce((sum, booking) => sum + booking.payments.reduce((paid, payment) => paid + toNumber(payment.amount), 0), 0)
        .toFixed(2)
    );

  res.json({
    serviceFeePercent: toNumber(setting.serviceFeePercent),
    income: {
      weekly: sumServiceFees(weekly),
      monthly: sumServiceFees(monthly),
      annual: sumServiceFees(annual),
      allTime: sumServiceFees(allTime),
      grossPaid: grossPaid(allTime),
      estimatedHostIncome: Number((grossPaid(allTime) - sumServiceFees(allTime)).toFixed(2)),
      completedBookings,
      recent: allTime.slice(0, 6).map((booking) => ({
        id: booking.id,
        venueName: booking.venue.name,
        eventDate: booking.eventDate,
        serviceFee: toNumber(booking.serviceFee),
        paid: booking.payments.reduce((sum, payment) => sum + toNumber(payment.amount), 0)
      }))
    }
  });
});

const updateServiceFee = asyncHandler(async (req, res) => {
  const serviceFeePercent = Number(req.body.serviceFeePercent);
  if (!Number.isFinite(serviceFeePercent) || serviceFeePercent < 0 || serviceFeePercent > 30) {
    throw new ApiError(400, 'Service fee must be between 0% and 30%.');
  }

  const oldSetting = await getPlatformSetting();
  const setting = await prisma.platformSetting.update({
    where: { id: 'platform' },
    data: { serviceFeePercent }
  });

  res.json({
    message: 'Service fee updated successfully.',
    oldServiceFeePercent: toNumber(oldSetting.serviceFeePercent),
    serviceFeePercent: toNumber(setting.serviceFeePercent)
  });
});

module.exports = {
  bookings,
  dashboard,
  hosts,
  incomeSummary,
  updateServiceFee,
  users,
  venues
};
