const request = require('supertest');
const app = require('../src/index');

describe('DevOps Demo API Tests', () => {
  describe('GET /', () => {
    it('should return app information', async () => {
      const response = await request(app).get('/');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('status');
      expect(response.body.message).toBe('DevOps Demo Application');
      expect(response.body.version).toBe('1.0.0');
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app).get('/health');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status');
      expect(response.body.status).toBe('healthy');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
      expect(response.body).toHaveProperty('cpu');
    });
  });

  describe('GET /metrics', () => {
    it('should return Prometheus metrics', async () => {
      const response = await request(app).get('/metrics');
      
      expect(response.status).toBe(200);
      expect(response.text).toContain('process_cpu_seconds_total');
      expect(response.text).toContain('nodejs_heap_size_total_bytes');
      expect(response.text).toContain('http_requests_total');
    });
  });

  describe('GET /api/data', () => {
    it('should return sample data', async () => {
      const response = await request(app).get('/api/data');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('description');
      expect(response.body).toHaveProperty('createdAt');
      expect(response.body).toHaveProperty('randomValue');
      expect(response.body.name).toBe('DevOps Demo Data');
    });
  });

  describe('POST /api/data', () => {
    it('should create new data', async () => {
      const newData = {
        name: 'Test Data',
        description: 'Test description'
      };
      
      const response = await request(app)
        .post('/api/data')
        .send(newData);
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('description');
      expect(response.body).toHaveProperty('createdAt');
      expect(response.body.name).toBe(newData.name);
      expect(response.body.description).toBe(newData.description);
    });

    it('should return error when name is missing', async () => {
      const response = await request(app)
        .post('/api/data')
        .send({ description: 'Test description' });
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toBe('Name is required');
    });
  });

  describe('404 handling', () => {
    it('should return 404 for non-existent routes', async () => {
      const response = await request(app).get('/non-existent-route');
      
      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toBe('Not found');
    });
  });

  describe('Error handling', () => {
    it('should handle errors gracefully', async () => {
      // This test ensures the error handling middleware works
      const response = await request(app)
        .post('/api/data')
        .send('invalid json');
      
      // Express json parser will fail before our route
      expect([400, 500]).toContain(response.status);
    });
  });
});