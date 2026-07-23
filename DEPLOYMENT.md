# راهنمای انتشار و ساخت نسخه — Bakery Manager

## ۱. بک‌اند (NestJS)

```bash
cd backend
cp .env.example .env   # مقادیر واقعی را در .env تنظیم کنید
npm install
npm run prisma:generate
npm run prisma:migrate
npm run prisma:seed
npm run build
npm run start:prod
```

یا با Docker:

```bash
docker build -t bakery-manager-backend ./backend
docker run -p 3000:3000 --env-file backend/.env bakery-manager-backend
```

## ۲. تست‌ها

```bash
cd backend
npm test          # تست‌های واحد (jest.config.js)
npm run test:cov  # تست با گزارش پوشش
npm run test:e2e  # تست‌های انتها به انتها (jest-e2e.json)
```

تست‌های واحد فعلی روی منطق حساس کسب‌وکار: ورود/خروج (Auth)، کشف انحراف تولید (Production)، قفل/بازکردن روز (Daily Closing)، لاطو فروش و بدهی مشتری (Sales)، و گزارش مصرف آرد (Flour Inventory) وجود دارد.

## ۳. پشتیبان‌گیری

- پشتیبان‌گیری روزانه از پایگاه‌داده به صورت خودکار ساعت ۳ بامداد اجرا می‌شود (`BackupService`) و با `pg_dump` یک نسخه SQL در مسیر `BACKUP_DIR` ذخیره می‌کند.
- پشتیبان‌های قدیمی‌تر از `BACKUP_RETENTION_DAYS` روز به صورت خودکار حذف می‌شوند.
- برای پشتیبان‌گیری دستی: `POST /backups/manual` (نیاز به دسترسی `roles.manage`).
- پیش‌نیاز: باید ابزار `pg_dump` در محیط اجرای باکند (مطابق با نسخه PostgreSQL سرور) نصب شده باشد.

## ۴. GitHub Actions (CI/CD) — نیازمند افزودن دستی

این اتصال تاکنون اجازه نوشتن در مسیر `.github/workflows/` را برای این مخزن ندارد (محدودیت دسترسی اتصال GitHub). محتوای کامل دو فایل workflow (بک‌اند و فلاتر) در پیام بعدی ارائه می‌شود تا خودتان آن را در مسیر `.github/workflows/` ریپوزیتوری اضافه کنید.

## ۵. ساخت نسخه APK اندروید (Flutter)

```bash
cd mobile
flutter pub get
flutter build apk --release
# خروجی: mobile/build/app/outputs/flutter-apk/app-release.apk
```

طبق اصل پروژه‌ی `فقط از طریق GitHub Actions ساخت می‌شود`، پس از افزوده‌شدن دسترسی workflow باید flutter-ci.yml را مطابق محتوای ارائه‌شده در تاریخچه این ریپوزیتوری افزوده و ادامه تیم build را از طریق اجرای این workflow دریافت کرد.
