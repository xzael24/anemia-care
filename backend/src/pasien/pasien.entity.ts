import { Column, Entity, PrimaryColumn } from 'typeorm';

export type Gender = 'laki' | 'perempuan';
export type TipeKulit = 'terang' | 'sedang' | 'gelap';

@Entity('pasien')
export class PasienEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ unique: true })
  username: string;

  @Column()
  passwordHash: string;

  @Column()
  nama: string;

  @Column({ type: 'int' })
  usia: number;

  @Column()
  gender: Gender;

  @Column({ type: 'varchar', nullable: true })
  tipeKulit: TipeKulit | null;

  @Column({ default: false })
  hamil: boolean;

  @Column({ default: false })
  riwayatAnemia: boolean;

  @Column({ type: 'timestamptz' })
  createdAt: Date;
}