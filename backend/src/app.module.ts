import { Module } from '@nestjs/common';
import { HealthController } from './modules/health/health.controller';
import { MmoModule } from './modules/mmo/mmo.module';
import { DatabaseModule } from './database/database.module';

@Module({
  imports: [DatabaseModule, MmoModule],
  controllers: [HealthController],
})
export class AppModule {}
