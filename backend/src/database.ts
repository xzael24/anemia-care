import { TypeOrmModule } from '@nestjs/typeorm';

/** Aktifkan persistensi Postgres saat env DB_HOST di-set (compose/mandiri). */
export const DB_ENABLED = !!process.env.DB_HOST;

/**
 * Root TypeORM — di-import AppModule SEKALI (satu DataSource).
 * Feature modules hanya pakai forFeature (conditional).
 */
export const typeOrmRootModule = DB_ENABLED
  ? TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT ?? 5432),
      username: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      autoLoadEntities: true,
      synchronize: true,
    })
  : null;