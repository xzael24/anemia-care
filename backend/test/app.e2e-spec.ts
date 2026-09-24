import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from './../src/app.module';

describe('Anemia Care API (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/health (GET) -> 200', () => {
    return request(app.getHttpServer()).get('/api/health').expect(200);
  });

  it('/api/screening (POST) tanpa foto -> 400', () => {
    return request(app.getHttpServer()).post('/api/screening').expect(400);
  });

  it('/api/screening (POST) dengan foto -> 200 (mode mock)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/screening')
      .attach('photo', Buffer.from([1, 2, 3, 4, 5]), {
        filename: 'kuku.png',
        contentType: 'image/png',
      })
      .expect(201);
    expect(res.body).toMatchObject({
      indication: expect.any(String),
      confidence: expect.any(Number),
      source: 'mock',
      disclaimer: expect.stringContaining('BUKAN diagnosis medis'),
    });
  });

  it('/api/screening (GET) -> riwayat berisi 1 entri', async () => {
    const res = await request(app.getHttpServer()).get('/api/screening').expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });
});