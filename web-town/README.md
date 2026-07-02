# Web Town PHP

مشروع ويب مستقل خارج مجلد `api`، لكنه مربوط بالـ API الحالي عبر `web-town/config.php`.

## التشغيل على XAMPP

ضع المجلدين بجانب بعض داخل `htdocs`:

- `htdocs/api`
- `htdocs/web-town`

ثم افتح:

- `http://localhost/api/health`
- `http://localhost/web-town/`

## الربط مع API

القيمة الافتراضية في `config.php` تستخدم:

`http://<host>/api/index.php`

وكل الطلبات تذهب بصيغة:

`index.php?r=route/name`

يمكن تغيير الرابط عبر متغير البيئة `WEB_TOWN_API_ENTRY` أو تعديل `config.php`.

## تسجيل الدخول الذكي

صفحة الدخول تحاول أولا `auth/admin/login`، فإذا كان الحساب `admin` أو `staff` يتم تحويله للوحة الإدارة. إذا لم يكن إداريا تستخدم `auth/login` وتحول المستخدم حسب:

- `customer` -> لوحة الزبون
- `office` + `is_marketer` غير مفعّل -> لوحة المكتب
- `office` + `is_marketer=1` -> لوحة المسوق
