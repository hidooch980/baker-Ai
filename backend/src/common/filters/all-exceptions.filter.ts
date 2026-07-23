import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Request, Response } from 'express';

const PERSIAN_MESSAGES: Record<number, string> = {
  400: 'درخواست نامعتبر است.',
  401: 'لطفاً وارد حساب کاربری خود شوید.',
  403: 'دسترسی به این بخش را ندارید.',
  404: 'مورد مورد نظر یافت نشد.',
  409: 'این عملیات با اطلاعات موجود تعارض دارد.',
  422: 'اطلاعات واردشده معتبر نیست.',
  429: 'درخواست‌های زیاد. کمی صبر کنید و دوباره تلاش کنید.',
  500: 'خطایی در سرور رخ داد. لطفاً دوباره تلاش کنید.',
};

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;

    const message = PERSIAN_MESSAGES[status] ?? PERSIAN_MESSAGES[500];

    this.logger.error(`${request.method} ${request.url} -> ${status}`, exception instanceof Error ? exception.stack : String(exception));

    response.status(status).json({
      statusCode: status,
      message,
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}
