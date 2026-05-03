const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const prisma = require('../config/prisma');
const { isEmailConfigured, sendPasswordResetEmail } = require('../services/emailService');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { publicUser, normalizeRole } = require('../utils/formatters');
const { signToken } = require('../utils/jwt');

const validatePassword = (password) => {
  if (!password || password.length < 8) {
    throw new ApiError(400, 'Password must be at least 8 characters long.');
  }
};

const tokenHash = (token) => crypto.createHash('sha256').update(token).digest('hex');

const updatePasswordWithToken = async ({ token, password, confirmPassword }) => {
  if (!token) {
    throw new ApiError(400, 'Reset token is required.');
  }

  validatePassword(password);
  if (password !== confirmPassword) {
    throw new ApiError(400, 'Password confirmation does not match.');
  }

  const user = await prisma.user.findFirst({
    where: {
      resetTokenHash: tokenHash(token),
      resetTokenExpires: { gt: new Date() }
    }
  });

  if (!user) {
    throw new ApiError(400, 'Reset link is invalid or expired.');
  }

  await prisma.user.update({
    where: { id: user.id },
    data: {
      password: await bcrypt.hash(password, 12),
      resetTokenHash: null,
      resetTokenExpires: null
    }
  });
};

const register = asyncHandler(async (req, res) => {
  const { email, password, name, gender, phone, profileImageUrl, role } = req.body;

  if (!email || !password || !name) {
    throw new ApiError(400, 'Name, email, and password are required.');
  }
  validatePassword(password);

  const existingUser = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (existingUser) {
    throw new ApiError(409, 'Email is already registered.');
  }

  const hashedPassword = await bcrypt.hash(password, 12);
  const user = await prisma.user.create({
    data: {
      email: email.toLowerCase(),
      password: hashedPassword,
      name,
      gender,
      phone,
      profileImageUrl,
      role: normalizeRole(role)
    }
  });

  res.status(201).json({
    token: signToken(user),
    user: publicUser(user)
  });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw new ApiError(400, 'Email and password are required.');
  }

  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (!user) {
    throw new ApiError(401, 'Invalid email or password.');
  }

  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) {
    throw new ApiError(401, 'Invalid email or password.');
  }

  res.json({
    token: signToken(user),
    user: publicUser(user)
  });
});

const me = asyncHandler(async (req, res) => {
  res.json({ user: publicUser(req.user) });
});

const forgotPassword = asyncHandler(async (req, res) => {
  const { email } = req.body;

  if (!email) {
    throw new ApiError(400, 'Email is required.');
  }

  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (!user) {
    throw new ApiError(404, 'No VenueHub account was found for that email.');
  }
  if (!isEmailConfigured()) {
    throw new ApiError(503, 'Email is not configured yet. Add SMTP settings or RESEND_API_KEY in Render, then try again.');
  }

  const token = crypto.randomBytes(24).toString('hex');
  const expires = new Date(Date.now() + 30 * 60 * 1000);

  await prisma.user.update({
    where: { id: user.id },
    data: {
      resetTokenHash: tokenHash(token),
      resetTokenExpires: expires
    }
  });

  const baseUrl = process.env.APP_BASE_URL || `${req.protocol}://${req.get('host')}`;
  const resetUrl = `${baseUrl}/api/auth/reset-password-page?token=${token}`;

  await sendPasswordResetEmail({ user, resetUrl, token });

  res.json({
    message: 'Password reset instructions were sent to your email.',
    ...(process.env.NODE_ENV !== 'production' && { resetToken: token })
  });
});

const resetPassword = asyncHandler(async (req, res) => {
  const { token, password, confirmPassword } = req.body;

  await updatePasswordWithToken({ token, password, confirmPassword });

  res.json({ message: 'Password updated successfully. You can now login.' });
});

const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword, confirmPassword } = req.body;

  if (!currentPassword) {
    throw new ApiError(400, 'Current password is required.');
  }

  validatePassword(newPassword);
  if (newPassword !== confirmPassword) {
    throw new ApiError(400, 'Password confirmation does not match.');
  }

  const isMatch = await bcrypt.compare(currentPassword, req.user.password);
  if (!isMatch) {
    throw new ApiError(401, 'Current password is incorrect.');
  }

  await prisma.user.update({
    where: { id: req.user.id },
    data: { password: await bcrypt.hash(newPassword, 12) }
  });

  res.json({ message: 'Password changed successfully.' });
});

const resetPasswordPage = asyncHandler(async (req, res) => {
  const token = req.query.token || '';

  res.type('html').send(`
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Reset VenueHub Password</title>
        <style>
          body{font-family:Arial,sans-serif;background:#eef7ff;color:#05264D;display:grid;place-items:center;min-height:100vh;margin:0}
          form{background:white;padding:28px;border-radius:20px;box-shadow:0 20px 50px rgba(5,38,77,.12);width:min(420px,90vw)}
          input,button{width:100%;box-sizing:border-box;padding:13px;margin-top:10px;border-radius:12px;border:1px solid #dce8f5}
          button{background:#05264D;color:white;font-weight:700;cursor:pointer}
        </style>
      </head>
      <body>
        <form method="post" action="/api/auth/reset-password-form">
          <h2>Reset VenueHub Password</h2>
          <input type="hidden" name="token" value="${String(token).replace(/"/g, '&quot;')}" />
          <input name="password" type="password" placeholder="New password" required minlength="8" />
          <input name="confirmPassword" type="password" placeholder="Confirm new password" required minlength="8" />
          <button type="submit">Update password</button>
        </form>
      </body>
    </html>
  `);
});

const resetPasswordForm = asyncHandler(async (req, res) => {
  await updatePasswordWithToken({
    token: req.body.token,
    password: req.body.password,
    confirmPassword: req.body.confirmPassword
  });

  res.type('html').send(`
        <div style="font-family:Arial,sans-serif;text-align:center;margin-top:60px;color:#05264D">
          <h2>Password updated</h2>
          <p>You can return to the VenueHub app and login with your new password.</p>
        </div>
      `);
});

module.exports = {
  changePassword,
  forgotPassword,
  login,
  me,
  register,
  resetPassword,
  resetPasswordForm,
  resetPasswordPage
};
