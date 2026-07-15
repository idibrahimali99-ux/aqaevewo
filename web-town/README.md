# Aqar Town — Web Town (PHP MVC)

نسخة ويب احترافية لمشروع **Aqar Town**، متصلة بنفس API وقاعدة بيانات تطبيقي Flutter (`real_estate_iraq` + `vewo_admin`) **بدون أي تغيير في المنطق أو الجداول**.

## المتطلبات

- PHP 8.3+
- Apache مع `mod_rewrite` (XAMPP)
- MySQL عبر API الموجود في `../api`

## التشغيل على XAMPP

```
htdocs/
  api/
  web-town/
```

- API: `http://localhost/api/health`
- الموقع: `http://localhost/web-town/`

## البنية (MVC Native)

```
web-town/
  config/app.php          # إعدادات التطبيق
  app/
    bootstrap.php         # Autoload + Session + Helpers
    Core/                 # App, Router, Controller, View
    Controllers/          # Public + Admin + User
    Models/ApiClient.php  # HTTP client للـ API
    Helpers/              # auth, csrf, admin, favorites
    Middleware/
  routes/web.php          # مسارات الموقع
  routes/admin.php        # مسارات لوحة الإدارة
  public/
    index.php             # Front controller
    assets/css|js/
  views/                  # Bootstrap 5.3 + RTL
```

## الربط مع API

كل البيانات عبر:

`{host}/api/index.php?r=route/name`

يمكن ضبط الرابط عبر `WEB_TOWN_API_ENTRY` أو `config/app.php`.

## الصفحات العامة

| المسار | الوصف |
|--------|--------|
| `/` | الرئيسية |
| `/properties`, `/search` | العقارات والبحث |
| `/property/{id}` | تفاصيل العقار |
| `/offices`, `/marketers` | المكاتب والمسوقون |
| `/login`, `/register` | المصادقة |
| `/favorites` | المفضلة (جلسة — نفس منطق التطبيق) |
| `/messages` | المحادثات (`chat/threads`) |
| `/notifications` | الإشعارات (`app/notifications/poll`) |
| `/profile` | الملف الشخصي |
| `/property/add` | إضافة إعلان (مكتب/مسوق) |
| `/user`, `/user/office`, `/user/marketer` | لوحات المستخدم |

## لوحة الإدارة

`/admin` — مطابقة لـ `vewo_admin` فقط:

overview, promotions, news, offices, governorates, parcels, compounds, properties, reels, property_requests, chats, users, marketers, posting_packages, reports, notifications, settings

## الأمان

- PHP Sessions + CSRF
- Prepared statements عبر API
- XSS escaping (`e()`)
- Role permissions للـ staff

## التصميم

- Bootstrap 5.3 RTL
- Font Awesome 6
- ApexCharts + DataTables (Admin)
- اللون الأساسي: `#F5B400`

## ملاحظات

- لا Laravel / CodeIgniter / Symfony — PHP Native OOP MVC
- لا اتصال مباشر بقاعدة البيانات من web-town
- تعديل المنشورات المنشورة غير مدعوم في API (نفس التطبيق — الإنشاء فقط عبر `properties/create`)
