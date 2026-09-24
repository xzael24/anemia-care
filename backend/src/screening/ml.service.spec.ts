import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { MlService } from './ml.service';

function makeService(env: Record<string, string>): MlService {
  const config = new ConfigService(env);
  return new MlService(config);
}

const fakeFile = (bytes: number[]): Express.Multer.File =>
  ({
    buffer: Buffer.from(bytes),
    originalname: 'kuku.png',
    mimetype: 'image/png',
    size: bytes.length,
  }) as Express.Multer.File;

describe('MlService', () => {
  it('tanpa ML_SERVICE_URL -> source "mock" dan confidence di rentang wajar', async () => {
    const svc = makeService({ ML_SERVICE_URL: '' });
    const { prediction, source } = await svc.predict(fakeFile([9, 9, 9]));
    expect(source).toBe('mock');
    expect(['anemia', 'normal']).toContain(prediction.label);
    expect(prediction.confidence).toBeGreaterThanOrEqual(0.3);
    expect(prediction.confidence).toBeLessThanOrEqual(0.7);
    expect(prediction.hbEstimateGdl).toBeNull();
  });

  it('deterministik: buffer sama -> label sama', async () => {
    const svc = makeService({ ML_SERVICE_URL: '' });
    const a = await svc.predict(fakeFile([42, 7]));
    const b = await svc.predict(fakeFile([42, 7]));
    expect(a.prediction.label).toBe(b.prediction.label);
  });

  it('sidecar tidak bisa dijangkau -> fallback ke mock, bukan error', async () => {
    const svc = makeService({ ML_SERVICE_URL: 'http://127.0.0.1:1' });
    const { source, prediction } = await svc.predict(fakeFile([1, 2, 3]));
    expect(source).toBe('mock');
    expect(prediction.label).toBeTruthy();
  }, 20_000);
});