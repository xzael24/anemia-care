import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';
import {
  GEJALA_OPTIONS,
  KULIT_OPTIONS,
  RISIKO_OPTIONS,
} from './fuzzy.service';

export class RekomendasiDto {
  @IsIn(['anemia', 'normal'])
  indication!: 'anemia' | 'normal';

  @IsNumber()
  @Min(0)
  @Max(1)
  confidence!: number;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  @Min(3)
  @Max(25)
  hbEstimateGdl?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(GEJALA_OPTIONS.length)
  @IsIn(GEJALA_OPTIONS, { each: true })
  gejala?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(RISIKO_OPTIONS.length)
  @IsIn(RISIKO_OPTIONS, { each: true })
  risiko?: string[];

  @IsOptional()
  @IsIn(KULIT_OPTIONS)
  tipeKulit?: 'terang' | 'sedang' | 'gelap';
}