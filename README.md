# Bakery Manager (نان‌بین)

سیستم جامع مدیریت نانوایی — Offline-First، فارسی و راست‌چین.

## پشته فنی
- **موبایل:** Flutter (Android، معماری آماده توسعه به iOS/Web)
- **بک‌اند:** NestJS + TypeScript
- **پایگاه داده:** PostgreSQL
- **ORM:** Prisma

## ساختار مخزن
```
backend/    # NestJS API + Prisma
mobile/     # اپلیکیشن Flutter
docs/       # معماری و نقشه‌راه
.github/    # CI/CD (GitHub Actions)
```

## وضعیت پروژه
این پروژه به‌صورت **مرحله‌ای (Phased)** ساخته می‌شود؛ نقشه کامل مراحل در [docs/ROADMAP.md](docs/ROADMAP.md) است.

### فاز ۱ — انجام‌شده ✅
- معماری کلی سیستم (`docs/ARCHITECTURE.md`)
- طرح کامل دیتابیس (`backend/prisma/schema.prisma`) با تمام مدل‌های اصلی بخش ۳۱ پرامپت
- احراز هویت JWT (Access + Refresh) و هش‌کردن رمز عبور
- سیستم RBAC کامل (Role / Permission / UserRole / RolePermission) + Guardهای سفارشی
- مدیریت کاربران (CRUD)
- Audit Log پایه (ثبت ورود/خروج و تغییرات حساس)
- Rate limiting، Validation، Helmet، CORS محدود، Swagger
- Docker Compose (PostgreSQL + Backend)
- CI/CD اولیه با GitHub Actions (Backend: lint/test/build، Flutter: analyze/test/build APK)
- اسکلت اپلیکیشن Flutter با RTL کامل، تقویم شمسی، فونت فارسی، ناوبری پایین (Bottom Navigation)

### فازهای بعدی (در حال توسعه)
محصولات و فروش، تولید و خمیر، آرد و مواد اولیه و سوخت، مشتریان/بدهکاران/تأمین‌کنندگان/خرید/هزینه‌ها، کارکنان و حقوق، بستن روزانه و حسابداری و گزارش‌ها، Sync آفلاین، هوش مصنوعی، امنیت/بکاپ/اعلان‌ها، تست و ریلیز — به ترتیب طبق `docs/ROADMAP.md`.

## راه‌اندازی سریع (توسعه محلی)
```bash
cp .env.example .env
docker compose up -d postgres
cd backend
cp .env.example .env
npm install
npx prisma migrate dev
npx prisma db seed
npm run start:dev
```
Swagger در آدرس: `http://localhost:3000/api/docs`

برای موبایل:
```bash
cd mobile
flutter pub get
flutter run
```

## اصول توسعه پروژه
- هیچ قابلیت ناقصی به‌عنوان کامل معرفی نمی‌شود.
- برای پول همیشه `Decimal` استفاده می‌شود، نه `Float`.
- داده مالی هرگز Hard Delete نمی‌شود؛ فقط Void/Cancel/Reverse/Soft Delete.
- APK فقط از طریق GitHub Actions ساخته می‌شود، نه از روی VPS.
