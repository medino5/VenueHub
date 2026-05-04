const prisma = require('../config/prisma');
const asyncHandler = require('../utils/asyncHandler');

const listNotifications = asyncHandler(async (req, res) => {
  const notifications = await prisma.notification.findMany({
    where: { userId: req.user.id },
    orderBy: { createdAt: 'desc' },
    take: 40
  });

  res.json({
    unreadCount: notifications.filter((notification) => !notification.readAt).length,
    notifications
  });
});

const markNotificationsRead = asyncHandler(async (req, res) => {
  await prisma.notification.updateMany({
    where: { userId: req.user.id, readAt: null },
    data: { readAt: new Date() }
  });

  res.json({ message: 'Notifications marked as read.' });
});

module.exports = {
  listNotifications,
  markNotificationsRead
};
