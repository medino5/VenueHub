const prisma = require('../config/prisma');
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

const dashboard = asyncHandler(async (_req, res) => {
  const [totalUsers, totalHosts, totalVenues, totalBookings, paidBookings] = await Promise.all([
    prisma.user.count(),
    prisma.user.count({ where: { role: 'HOST' } }),
    prisma.venue.count(),
    prisma.booking.count(),
    prisma.booking.findMany({ where: { paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] } } })
  ]);

  res.json({
    dashboard: {
      totalUsers,
      totalHosts,
      totalVenues,
      totalBookings,
      platformIncome: sumServiceFees(paidBookings),
      serviceFeePercent: 10
    }
  });
});

const users = asyncHandler(async (_req, res) => {
  const allUsers = await prisma.user.findMany({ orderBy: { createdAt: 'desc' } });
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
  const [weekly, monthly, annual, allTime] = await Promise.all([
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(7) } } }),
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(30) } } }),
    prisma.booking.findMany({ where: { ...paidWhere, createdAt: { gte: startOfWindow(365) } } }),
    prisma.booking.findMany({ where: paidWhere })
  ]);

  res.json({
    serviceFeePercent: 10,
    income: {
      weekly: sumServiceFees(weekly),
      monthly: sumServiceFees(monthly),
      annual: sumServiceFees(annual),
      allTime: sumServiceFees(allTime)
    }
  });
});

module.exports = {
  bookings,
  dashboard,
  hosts,
  incomeSummary,
  users,
  venues
};
