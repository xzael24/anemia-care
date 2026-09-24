import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from './../src/app.module';

describe('Anemia Care API (e2e)', () => {
  let app: INestApplication;
  let token = '';
  let createdId = '';

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

  it('/api/auth/login password salah -> 401', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'salah' })
      .expect(401);
  });

  it('/api/screening (POST) tanpa foto -> 400', () => {
    return request(app.getHttpServer()).post('/api/screening').expect(400);
  });

  it('/api/screening (GET) tanpa token -> 401', () => {
    return request(app.getHttpServer()).get('/api/screening').expect(401);
  });

  it('/api/screening (POST) dengan foto -> 201 (mode mock)', async () => {
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
      status: 'baru',
      disclaimer: expect.stringContaining('BUKAN diagnosis medis'),
    });
    createdId = res.body.id;
  });

  it('/api/auth/login benar -> accessToken', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'admin123' })
      .expect(201);
    expect(res.body.accessToken).toEqual(expect.any(String));
    expect(res.body.petugas.role).toBe('admin');
    token = res.body.accessToken;
  });

  it('/api/screening (GET) dengan token -> 200 & riwayat berisi entri', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/screening')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });

  it('/api/screening/:id/verify dengan token -> status terverifikasi', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/screening/${createdId}/verify`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body).toMatchObject({
      id: createdId,
      status: 'terverifikasi',
      verifiedBy: 'admin',
    });
    expect(res.body.verifiedAt).toEqual(expect.any(String));
  });

  it('/api/screening/:id/verify tanpa token -> 401', async () => {
    await request(app.getHttpServer())
      .patch(`/api/screening/${createdId}/verify`)
      .expect(401);
  });

  it('/api/rekomendasi (POST) valid: normal tanpa konteks -> rendah', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/rekomendasi')
      .send({ indication: 'normal', confidence: 0.9 })
      .expect(201);
    expect(res.body).toMatchObject({
      tingkat: 'rendah',
      label: expect.stringContaining('pola makan'),
      skor: expect.objectContaining({ visual: expect.any(Number) }),
    });
    expect(Array.isArray(res.body.aturanAktif)).toBe(true);
    expect(res.body.disclaimer).toContain('BUKAN pengganti tenaga kesehatan');
  });

  it('/api/rekomendasi (POST) valid: anemia + hamil + gejala -> tinggi', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/rekomendasi')
      .send({
        indication: 'anemia',
        confidence: 0.92,
        gejala: ['pusing', 'lemas'],
        risiko: ['hamil'],
        tipeKulit: 'gelap',
      })
      .expect(201);
    expect(res.body.tingkat).toBe('tinggi');
    expect(res.body.label).toContain('puskesmas');
    expect(res.body.emoji).toBe('🔴');
  });

  it('/api/rekomendasi (POST) confidence di luar 0..1 -> 400', () => {
    return request(app.getHttpServer())
      .post('/api/rekomendasi')
      .send({ indication: 'anemia', confidence: 1.5 })
      .expect(400);
  });

  it('/api/rekomendasi (POST) gejala tidak dikenal -> 400', () => {
    return request(app.getHttpServer())
      .post('/api/rekomendasi')
      .send({ indication: 'anemia', confidence: 0.5, gejala: ['flu'] })
      .expect(400);
  });

  it('/api/rekomendasi/aturan (GET) -> 12 rule Mamdani', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/rekomendasi/aturan')
      .expect(200);
    expect(res.body.input).toEqual(['visual', 'gejala', 'risiko']);
    expect(res.body.rules).toHaveLength(12);
  });

  it('/api/pasien daftar + login + me (POST/GET)', async () => {
    const server = app.getHttpServer();
    const daftar = await request(server)
      .post('/api/pasien/daftar')
      .send({
        username: 'Sari23',
        password: 'rahasia123',
        nama: 'Sari Amalia',
        usia: 24,
        gender: 'perempuan',
        tipeKulit: 'sedang',
        hamil: true,
      })
      .expect(201);
    expect(daftar.body.accessToken).toBeDefined();
    expect(daftar.body.pasien).toMatchObject({
      username: 'sari23',
      nama: 'Sari Amalia',
      usia: 24,
      gender: 'perempuan',
      tipeKulit: 'sedang',
      hamil: true,
    });
    // DTO validasi: username pendek / password pendek / usia aneh → 400
    await request(server)
      .post('/api/pasien/daftar')
      .send({ username: 'a', password: 'x', nama: 'X', usia: 0, gender: 'x' })
      .expect(400);

    // Duplikat username → 409
    await request(server)
      .post('/api/pasien/daftar')
      .send({
        username: 'sari23',
        password: 'lain123',
        nama: 'Sari 2',
        usia: 30,
        gender: 'perempuan',
      })
      .expect(409);

    const login = await request(server)
      .post('/api/pasien/login')
      .send({ username: 'sari23', password: 'rahasia123' })
      .expect(201);
    expect(login.body.accessToken).toBeDefined();

    await request(server)
      .post('/api/pasien/login')
      .send({ username: 'sari23', password: 'salah' })
      .expect(401);

    // /me: tanpa token 401 · token petugas 403 · token pasien 200
    await request(server).get('/api/pasien/me').expect(401);
    await request(server)
      .get('/api/pasien/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
    const me = await request(server)
      .get('/api/pasien/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);
    expect(me.body.username).toBe('sari23');
  });

  it('/api/screening dengan token pasien → pasienId terisi + riwayat per akun', async () => {
    const server = app.getHttpServer();
    const login = await request(server)
      .post('/api/pasien/login')
      .send({ username: 'sari23', password: 'rahasia123' })
      .expect(201);

    const created = await request(server)
      .post('/api/screening')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .attach('photo', Buffer.from([1, 2, 3, 4, 5]), {
        filename: 'kuku.png',
        contentType: 'image/png',
      })
      .expect(201);
    expect(created.body.pasienId).toBe(login.body.pasien.id);

    // Screening anonim (tanpa token) tetap berjalan, pasienId null.
    const anonim = await request(server)
      .post('/api/screening')
      .attach('photo', Buffer.from([1, 2, 3, 4, 5]), {
        filename: 'kuku2.png',
        contentType: 'image/png',
      })
      .expect(201);
    expect(anonim.body.pasienId).toBeNull();

    const riwayat = await request(server)
      .get('/api/pasien/me/skrining')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);
    expect(Array.isArray(riwayat.body)).toBe(true);
    expect(riwayat.body.some((r: { id: string }) => r.id === created.body.id)).toBe(true);
    expect(riwayat.body.some((r: { id: string }) => r.id === anonim.body.id)).toBe(false);

    // Tanpa token pasien → 401 untuk riwayat akun
    await request(server).get('/api/pasien/me/skrining').expect(401);
  });
});