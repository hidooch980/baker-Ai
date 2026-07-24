# راهنمای نصب آیکون اپ و اسپلش‌اسکرین

این مخزن اکنون پیکربندی `flutter_launcher_icons` و `flutter_native_splash` را در `pubspec.yaml` دارد،
اما چون این محیط دسترسی به Flutter SDK و شبکه ندارد، دو فایل تصویر باید توسط شما اضافه شوند
(در پاسخ چت، این دو تصویر برای دانلود در دسترس هستند):

1. `icon.png` (۱۰۲۴×۱۰۲۴) → در مسیر `mobile/assets/icon/icon.png` قرار دهید.
2. `splash_logo.png` (۴۸۰×۴۸۰) → در مسیر `mobile/assets/icon/splash_logo.png` قرار دهید.

سپس این دستورها را در پوشه `mobile/` اجرا کنید:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
dart run flutter_native_splash:create
```

این دستورها به‌صورت خودکار:
- آیکون اپ را برای Android و iOS در همه رزولوشن‌های لازم می‌سازند.
- اسپلش‌اسکرین بومی (native) را با رنگ پس‌زمینه هماهنگ با کارت آیکون (`#FCEDCE`) تولید می‌کنند.

در صورت تغییر بعدی آیکون، کافی است دو فایل تصویر را جایگزین کرده و دستورهای بالا را دوباره اجرا کنید.
