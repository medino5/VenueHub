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
  Number(bookings.reduce((sum, booking) => sum + realizedServiceFee(booking), 0).toFixed(2));

const paidAmount = (booking) =>
  (booking.payments || []).reduce((sum, payment) => sum + toNumber(payment.amount), 0);

const realizedServiceFee = (booking) => {
  const total = toNumber(booking.totalAmount);
  if (!total) return 0;
  const ratio = Math.min(paidAmount(booking) / total, 1);
  return toNumber(booking.serviceFee) * ratio;
};

const grossPaid = (bookings) => Number(bookings.reduce((sum, booking) => sum + paidAmount(booking), 0).toFixed(2));

const lastMonthBuckets = (count = 6) => {
  const now = new Date();
  return Array.from({ length: count }).map((_, index) => {
    const date = new Date(now.getFullYear(), now.getMonth() - (count - index - 1), 1);
    return {
      key: `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`,
      label: date.toLocaleString('en', { month: 'short' }),
      grossPaid: 0,
      platformFees: 0,
      bookings: 0
    };
  });
};

const getPlatformSetting = () =>
  prisma.platformSetting.upsert({
    where: { id: 'platform' },
    update: {},
    create: { id: 'platform', serviceFeePercent: 10 }
  });

const dashboard = asyncHandler(async (_req, res) => {
  const [
    totalUsers,
    totalCustomers,
    totalHosts,
    totalVenues,
    pendingVenues,
    totalBookings,
    pendingBookings,
    unpaidBookings,
    approvedBookings,
    rejectedBookings,
    completedBookings,
    paidBookings,
    allBookings,
    recentBookings,
    setting
  ] = await Promise.all([
    prisma.user.count(),
    prisma.user.count({ where: { role: 'CUSTOMER' } }),
    prisma.user.count({ where: { role: 'HOST' } }),
    prisma.venue.count(),
    prisma.venue.count({ where: { status: 'PENDING' } }),
    prisma.booking.count(),
    prisma.booking.count({ where: { status: 'PENDING' } }),
    prisma.booking.count({ where: { status: { in: ['PENDING', 'APPROVED'] }, paymentStatus: 'UNPAID' } }),
    prisma.booking.count({ where: { status: 'APPROVED' } }),
    prisma.booking.count({ where: { status: 'REJECTED' } }),
    prisma.booking.count({ where: { status: 'COMPLETED' } }),
    prisma.booking.findMany({ where: { paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] } }, include: { payments: true } }),
    prisma.booking.findMany({ include: { payments: true } }),
    prisma.booking.findMany({
      include: {
        customer: { select: { name: true } },
        venue: { select: { name: true } },
        payments: true
      },
      orderBy: { createdAt: 'desc' },
      take: 6
    }),
    getPlatformSetting()
  ]);

  const outstandingBalance = allBookings.reduce((sum, booking) => {
    if (!['PENDING', 'APPROVED'].includes(booking.status) || booking.paymentStatus === 'PAID') return sum;
    return sum + Math.max(toNumber(booking.totalAmount) - paidAmount(booking), 0);
  }, 0);
  const approvalRate = totalBookings ? Number(((approvedBookings + completedBookings) / totalBookings * 100).toFixed(1)) : 0;

  res.json({
    dashboard: {
      totalUsers,
      totalCustomers,
      totalHosts,
      totalVenues,
      pendingVenues,
      totalBookings,
      pendingBookings,
      unpaidBookings,
      approvedBookings,
      rejectedBookings,
      completedBookings,
      paidBookings: paidBookings.length,
      grossPaid: grossPaid(paidBookings),
      platformIncome: sumServiceFees(paidBookings),
      outstandingBalance: Number(outstandingBalance.toFixed(2)),
      approvalRate,
      serviceFeePercent: toNumber(setting.serviceFeePercent),
      recentActivity: recentBookings.map((booking) => ({
        id: booking.id,
        customerName: booking.customer?.name || 'Customer',
        venueName: booking.venue?.name || 'Venue',
        status: booking.status,
        paymentStatus: booking.paymentStatus,
        totalAmount: toNumber(booking.totalAmount),
        paid: paidAmount(booking),
        createdAt: booking.createdAt
      }))
    }
  });
});

const users = asyncHandler(async (_req, res) => {
  const allUsers = await prisma.user.findMany({
    include: {
      bookings: {
        select: {
          id: true,
          status: true,
          paymentStatus: true,
          eventDate: true,
          totalAmount: true,
          venue: { select: { name: true } }
        },
        orderBy: { createdAt: 'desc' }
      },
      venues: {
        select: {
          id: true,
          name: true,
          status: true,
          location: true
        },
        orderBy: { createdAt: 'desc' }
      }
    },
    orderBy: { createdAt: 'desc' }
  });
  res.json({
    users: allUsers.map((user) => {
      const safeUser = publicUser(user);
      const { bookings, venues, ...profile } = safeUser;

      return {
        ...profile,
        bookingCount: bookings.length,
        venueCount: venues.length,
        recentBookings: bookings.slice(0, 3).map((booking) => ({
          id: booking.id,
          venueName: booking.venue?.name || 'Venue',
          status: booking.status,
          paymentStatus: booking.paymentStatus,
          eventDate: booking.eventDate,
          totalAmount: toNumber(booking.totalAmount)
        })),
        venueSummaries: venues.slice(0, 4)
      };
    })
  });
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
  const [allTime, allBookings, completedBookings, setting] = await Promise.all([
    prisma.booking.findMany({ where: paidWhere, include: { payments: true, venue: true, customer: { select: { name: true } } }, orderBy: { createdAt: 'desc' } }),
    prisma.booking.findMany({ include: { payments: true } }),
    prisma.booking.count({ where: { status: 'COMPLETED' } }),
    getPlatformSetting()
  ]);

  const weekly = allTime.filter((booking) => booking.createdAt >= startOfWindow(7));
  const monthly = allTime.filter((booking) => booking.createdAt >= startOfWindow(30));
  const annual = allTime.filter((booking) => booking.createdAt >= startOfWindow(365));
  const paymentBreakdown = allTime.reduce(
    (summary, booking) => {
      (booking.payments || []).forEach((payment) => {
        const key = payment.type.toLowerCase();
        summary[key] = Number(((summary[key] || 0) + toNumber(payment.amount)).toFixed(2));
      });
      return summary;
    },
    { deposit: 0, balance: 0, full: 0 }
  );
  const statusBreakdown = allBookings.reduce((summary, booking) => {
    summary[booking.status] = (summary[booking.status] || 0) + 1;
    return summary;
  }, {});
  const outstandingBalance = allBookings.reduce((sum, booking) => {
    if (!['PENDING', 'APPROVED'].includes(booking.status) || booking.paymentStatus === 'PAID') return sum;
    return sum + Math.max(toNumber(booking.totalAmount) - paidAmount(booking), 0);
  }, 0);
  const buckets = lastMonthBuckets(6);
  const bucketMap = new Map(buckets.map((bucket) => [bucket.key, bucket]));
  allTime.forEach((booking) => {
    const date = booking.createdAt;
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    const bucket = bucketMap.get(key);
    if (!bucket) return;
    bucket.grossPaid = Number((bucket.grossPaid + paidAmount(booking)).toFixed(2));
    bucket.platformFees = Number((bucket.platformFees + realizedServiceFee(booking)).toFixed(2));
    bucket.bookings += 1;
  });

  res.json({
    serviceFeePercent: toNumber(setting.serviceFeePercent),
    income: {
      weekly: sumServiceFees(weekly),
      monthly: sumServiceFees(monthly),
      annual: sumServiceFees(annual),
      allTime: sumServiceFees(allTime),
      grossPaid: grossPaid(allTime),
      estimatedHostIncome: Number((grossPaid(allTime) - sumServiceFees(allTime)).toFixed(2)),
      outstandingBalance: Number(outstandingBalance.toFixed(2)),
      averagePlatformFee: allTime.length ? Number((sumServiceFees(allTime) / allTime.length).toFixed(2)) : 0,
      paidBookingCount: allTime.length,
      completedBookings,
      paymentBreakdown,
      statusBreakdown,
      monthlyTrend: buckets,
      recent: allTime.slice(0, 8).map((booking) => ({
        id: booking.id,
        venueName: booking.venue.name,
        customerName: booking.customer?.name || 'Customer',
        eventDate: booking.eventDate,
        serviceFee: Number(realizedServiceFee(booking).toFixed(2)),
        paid: paidAmount(booking),
        status: booking.status,
        paymentStatus: booking.paymentStatus
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
