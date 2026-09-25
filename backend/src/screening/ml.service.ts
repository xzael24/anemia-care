import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'node:crypto';

export interface MlPrediction {
  label: 'anemia' | 'normal';
  confidence: number;
  hbEstimateGdl: number | null;
}

export interface MlResult {
  prediction: MlPrediction;
  source: 'ml' | 'mock';
}

/**
 * Adapter ke sidecar ML (FastAPI). Kontrak:
 * POST {ML_SERVICE_URL}/predict  (multipart field "file")
 * POST {ML_SERVICE_URL}/predict-hand  (foto tangan penuh → PCD otomatis)
 * -> 200 { "label": "anemia"|"normal", "probability": 0-1,
 *          "hb_estimate_gdl": number|null, "model": "string" }
 * Untuk predict-hand label memakai THRESHOLD_HAND (0.25) di sidecar.
 *
 * Selama sidecar belum aktif (ML_SERVICE_URL kosong / gagal),
 * fallback ke prediksi deterministik yang JELAS berlabel "mock".
 */
@Injectable()
export class MlService {
  constructor(private readonly config: ConfigService) {}

  get isConfigured(): boolean {
    const url = this.config.get<string>('ML_SERVICE_URL');
    return Boolean(url && url.trim().length > 0);
  }

  async predict(
    file: Express.Multer.File,
    mode: 'closeup' | 'hand' = 'closeup',
  ): Promise<MlResult> {
    if (!this.isConfigured || !file.buffer?.length) {
      return { prediction: this.mockPredict(file), source: 'mock' };
    }

    const baseUrl = this.config.get<string>('ML_SERVICE_URL')!.replace(/\/+$/, '');
    try {
      const form = new FormData();
      form.append(
        'file',
        new Blob([new Uint8Array(file.buffer)], {
          type: file.mimetype || 'image/jpeg',
        }),
        file.originalname || 'photo.jpg',
      );
      // mode=hand -> foto tangan penuh -> sidecar jalankan PCD (segmentasi
      // kuku otomatis) sebelum ekstraksi fitur; endpoint & threshold beda.
      const endpoint = mode === 'hand' ? '/predict-hand' : '/predict';
      const res = await fetch(`${baseUrl}${endpoint}`, {
        method: 'POST',
        body: form,
        signal: AbortSignal.timeout(15_000),
      });
      if (!res.ok) throw new Error(`ML service HTTP ${res.status}`);
      const data = (await res.json()) as Record<string, unknown>;
      return {
        prediction: {
          label: data.label === 'anemia' ? 'anemia' : 'normal',
          confidence: clamp01(
            Number(data.probability ?? data.confidence ?? 0.5),
          ),
          hbEstimateGdl:
            data.hb_estimate_gdl != null ? Number(data.hb_estimate_gdl) : null,
        },
        source: 'ml',
      };
    } catch (err) {
      console.warn(
        `[ml] sidecar gagal (${(err as Error).message}) - fallback mock`,
      );
      return { prediction: this.mockPredict(file), source: 'mock' };
    }
  }

  /** Fallback deterministik dari isi file (BUKAN prediksi nyata). */
  private mockPredict(file: Express.Multer.File): MlPrediction {
    const digest = createHash('sha256').update(file.buffer).digest();
    const base = digest[0] / 255; // 0..1 dari isi file (bukan random murni)
    const confidence = Math.round((0.35 + base * 0.3) * 1000) / 1000;
    return {
      label: base >= 0.5 ? 'anemia' : 'normal',
      confidence,
      hbEstimateGdl: null,
    };
  }
}

function clamp01(v: number): number {
  return Math.min(1, Math.max(0, v));
}