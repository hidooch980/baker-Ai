import { Controller, Get, Query, Res } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { ReportsService } from './reports.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';

@ApiTags('reports')
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @RequirePermissions('reports.view')
  @Get('profit-loss')
  profitAndLoss(@Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.reportsService.profitAndLoss(new Date(startDate), new Date(endDate));
  }

  @RequirePermissions('reports.view')
  @Get('sales')
  salesReport(@Query('startDate') startDate: string, @Query('endDate') endDate: string) {
    return this.reportsService.salesReport(new Date(startDate), new Date(endDate));
  }

  @RequirePermissions('reports.view')
  @Get('export/sales.csv')
  async exportSalesCsv(@Query('startDate') startDate: string, @Query('endDate') endDate: string, @Res({ passthrough: true }) res: Response) {
    const csv = await this.reportsService.exportSalesCsv(new Date(startDate), new Date(endDate));
    res.header('Content-Type', 'text/csv; charset=utf-8');
    res.header('Content-Disposition', 'attachment; filename="sales-report.csv"');
    return csv;
  }

  @RequirePermissions('reports.view')
  @Get('export/sales.xlsx')
  async exportSalesExcel(@Query('startDate') startDate: string, @Query('endDate') endDate: string, @Res() res: Response) {
    const buffer = await this.reportsService.exportSalesExcel(new Date(startDate), new Date(endDate));
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename="sales-report.xlsx"',
    });
    res.send(buffer);
  }

  @RequirePermissions('reports.view')
  @Get('export/profit-loss.pdf')
  async exportProfitLossPdf(@Query('startDate') startDate: string, @Query('endDate') endDate: string, @Res() res: Response) {
    const buffer = await this.reportsService.exportProfitLossPdf(new Date(startDate), new Date(endDate));
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'attachment; filename="profit-loss.pdf"',
    });
    res.send(buffer);
  }
}
