import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

const INSECURE_DEFAULT_SECRETS = ['change_me_access_secret', 'change_me_refresh_secret'];

/** جلوگیری از بالا آمدن سرور در محیط production با کلیدهای JWT پیش‌فرض/تکراری (خطر امنیتی جدی). */
function assertSecureJwtSecrets(config: ConfigService) {
  if (config.get<string>('nodeEnv') !== 'production') return;

  const accessSecret = config.get<string>('jwt.accessSecret');
  const refreshSecret = config.get<string>('jwt.refreshSecret');

  if (
    !accessSecret ||
    !refreshSecret ||
    INSECURE_DEFAULT_SECRETS.includes(accessSecret) ||
    INSECURE_DEFAULT_SECRETS.includes(refreshSecret) ||
    accessSecret === refreshSecret
  ) {
    throw new Error(
      'در محیط production باید JWT_ACCESS_SECRET و JWT_REFRESH_SECRET با مقادیر امن، طولانی و متفاوت از یکدیگر تنظیم شوند (نه مقادیر پیش‌فرض).',
    );
  }
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  assertSecureJwtSecrets(config);

  app.use(helmet());
  app.enableCors({
    origin: config.get<string>('CORS_ORIGIN', 'http://localhost:3000'),
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Bakery Manager API')
    .setDescription('API مدیریت نانوایی')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = config.get<number>('PORT', 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Bakery Manager API is running on port ${port}`);
}

bootstrap();
