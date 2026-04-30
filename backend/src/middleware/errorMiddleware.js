const notFound = (req, _res, next) => {
  const error = new Error(`Route not found: ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
};

const errorHandler = (error, _req, res, _next) => {
  const statusCode = error.statusCode || 500;

  res.status(statusCode).json({
    message: error.message || 'Something went wrong.',
    ...(process.env.NODE_ENV !== 'production' && { stack: error.stack })
  });
};

module.exports = { errorHandler, notFound };
