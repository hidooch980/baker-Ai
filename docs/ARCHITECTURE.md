# معماری سیستم Bakery Manager

## معماری کلی
```
Flutter App
  -> Local Database (SQLite/Drift)
  -> Sync Engine (Sync Queue)
  -> REST API (HTTPS)
  -> NestJS Controllers
  -> NestJS Services
  -> Prisma ORM
  -> PostgreSQL
```

## لایه هوش مصنوعی
```
NestJS -> AI Module -> Secure Data Access Layer (فقط Read، محدود به دیتای واقعی) -> Analytics/Forecast Engine
```

## اصول معماری Backend
- Modular: هر دومین کسب‌وکار (Sales، Production، Flour، ...) یک ماژول مستقل NestJS است.
- هر ماژول: `module.ts` + `controller.ts` + `service.ts` + `dto/`.
- دسترسی به دیتابیس فقط از طریق `PrismaService` مشترک.
- Guardهای سراسری: `JwtAuthGuard` (احراز هویت) و `PermissionsGuard` (RBAC) روی همه Endpointهای غیرعمومی.
- اعتبارسنجی ورودی با `class-validator` روی همه DTOها (`ValidationPipe` سراسری با `whitelist` و `forbidNonWhitelisted`).
- خطاها با `AllExceptionsFilter` به فرمت یکسان و پیام فارسی ساده بازگردانده می‌شوند.
- عملیات حساس (ورود/خروج، ایجاد/ویرایش/حذف مالی، تغییر قیمت، بستن/بازکردن روز، تغییر Permission) در `AuditLog` ثبت می‌شوند.

## Offline-First (نقشه راه فاز ۷)
- هر رکورد قابل ثبت آفلاین دارای فیلدهای `id (UUID)`, `createdAt`, `updatedAt`, `deletedAt`, `version`, `syncStatus` است (از هم‌اکنون در Prisma Schema لحاظ شده).
- مسیر Sync: `Client Local DB -> Sync Queue -> POST /sync -> Server` با تفکیک `syncStatus: PENDING | SYNCED | CONFLICT | FAILED`.
- سیاست Conflict Resolution (فاز ۷): «آخرین نگارش برنده است بر اساس `version` + ثبت نسخه بازنده در `AuditLog` برای بازرسی؛ هیچ داده‌ای بی‌صدا از بین نمی‌رود.»

## امنیت
- JWT Access (کوتاه‌مدت) + Refresh Token (بلندمدت، قابل باطل‌شدن).
- Password Hashing با bcrypt.
- Helmet برای هدرهای امنیتی، CORS محدود به Origin مشخص، Rate Limiting با `@nestjs/throttler`.
- هیچ Secret در Git commit نمی‌شود؛ همه از طریق `.env` (که در `.gitignore` است).

## دیتابیس
- شرح کامل مدل‌ها در `backend/prisma/schema.prisma`.
- پول همیشه `Decimal(14,2)` — هرگز `Float`.
- داده مالی حساس Soft Delete می‌شود (`deletedAt`)؛ حذف فیزیکی نداریم.
