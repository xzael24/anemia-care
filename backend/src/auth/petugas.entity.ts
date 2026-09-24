import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('petugas')
export class PetugasEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ unique: true })
  username: string;

  @Column()
  passwordHash: string;

  @Column()
  name: string;

  @Column()
  role: 'admin' | 'petugas';
}