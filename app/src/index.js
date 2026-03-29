const express = require('express');
const { createLogger, transports, format } = require('winston');
const client = require('prom-client');

// 创建日志记录器
const logger = createLogger({
  level: 'info',
  format: format.combine(
    format.timestamp(),
    format.json()
  ),
  transports: [
    new transports.Console(),
    new transports.File({ filename: 'logs/error.log', level: 'error' }),
    new transports.File({ filename: 'logs/combined.log' })
  ]
});

// 创建 Prometheus 指标
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  registers: [register]
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'code'],
  registers: [register]
});

const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

const app = express();
let activeConnectionsCount = 0;

// 中间件
app.use(express.json());
app.use((req, res, next) => {
  const start = Date.now();
  
  activeConnectionsCount++;
  activeConnections.set(activeConnectionsCount);
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      code: res.statusCode.toString()
    };
    
    httpRequestDuration.observe(labels, duration);
    httpRequestsTotal.inc(labels);
    
    activeConnectionsCount--;
    activeConnections.set(activeConnectionsCount);
    
    logger.info({
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: duration
    });
  });
  
  next();
});

// 路由
app.get('/', (req, res) => {
  res.json({
    message: 'DevOps Demo Application',
    version: '1.0.0',
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage()
  });
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.toString());
  }
});

app.get('/api/data', (req, res) => {
  const data = {
    id: 1,
    name: 'DevOps Demo Data',
    description: 'Sample API response',
    createdAt: new Date().toISOString(),
    randomValue: Math.random()
  };
  res.json(data);
});

app.post('/api/data', (req, res) => {
  const { name, description } = req.body;
  
  if (!name) {
    return res.status(400).json({
      error: 'Name is required'
    });
  }
  
  const data = {
    id: Date.now(),
    name,
    description: description || 'No description provided',
    createdAt: new Date().toISOString()
  };
  
  res.status(201).json(data);
});

// 错误处理
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// 404 处理
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.path
  });
});

const PORT = process.env.PORT || 8080;

const server = app.listen(PORT, () => {
  logger.info(`Server started on port ${PORT}`);
  logger.info(`Health check: http://localhost:${PORT}/health`);
  logger.info(`Metrics: http://localhost:${PORT}/metrics`);
});

// 优雅关闭
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

module.exports = app;