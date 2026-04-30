const bcrypt = require('bcryptjs');

const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { publicUser, normalizeRole } = require('../utils/formatters');
const { signToken } = require('../utils/jwt');

const register = asyncHandler(async (req, res) => {
  const { email, password, name, gender, phone, profileImageUrl, role } = req.body;

  if (!email || !password || !name) {
    throw new ApiError(400, 'Name, email, and password are required.');
  }

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

module.exports = { login, me, register };
