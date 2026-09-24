import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class DaftarDto {
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_.-]+$/, {
    message: 'username hanya boleh huruf, angka, _, -, titik',
  })
  username!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  nama!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(120)
  usia!: number;

  @IsIn(['laki', 'perempuan'])
  gender!: 'laki' | 'perempuan';

  @IsOptional()
  @IsIn(['terang', 'sedang', 'gelap'])
  tipeKulit?: 'terang' | 'sedang' | 'gelap';

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  hamil?: boolean;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  riwayatAnemia?: boolean;
}

export class LoginPasienDto {
  @IsString()
  username!: string;

  @IsString()
  password!: string;
}
