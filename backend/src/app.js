const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const routes = require('./routes');
const { notFound, errorHandler } = require('./middleware/errorMiddleware');

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CLIENT_ORIGIN || '*' }));
app.use(express.json({ limit: '25mb' }));
app.use(morgan('dev'));

app.get('/', (_req, res) => {
  res.json({
    name: 'VenueHub API',
    status: 'online',
    docs: '/api/health'
  });
});

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', service: 'venuehub-api' });
});

app.use('/api', routes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
