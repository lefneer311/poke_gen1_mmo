import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  async health(): Promise<{ status: 'ok'; database: 'ok'; uptimeSeconds: number }> {
    await this.database.assertHealthy();
    return { status: 'ok', database: 'ok', uptimeSeconds: Math.floor(process.uptime()) };
  }
}
