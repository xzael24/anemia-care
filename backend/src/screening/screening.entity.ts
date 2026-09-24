import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('screening')
export class ScreeningEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column()
  indication: 'anemia' | 'normal';

  @Column({ type: 'double precision' })
  confidence: number;

  @Column({ type: 'double precision', nullable: true })
  hbEstimateGdl: number | null;

  @Column()
  source: 'ml' | 'mock';

  @Column()
  imageName: string;

  @Column({ type: 'timestamptz' })
  createdAt: Date;
}