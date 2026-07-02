# vewo API (PHP + XAMPP)

## التثبيت على السيرفر

1. انسخ المجلد **`api`** بالكامل إلى:
   - `C:\xampp\htdocs\api`

2. أنشئ قاعدة البيانات واستورد المخطط:
   - من phpMyAdmin نفّذ محتوى الملف:  
     `../backend/db/init.mysql.sql`

3. انسخ الإعدادات:
   - انسخ `config.example.php` إلى **`config.php`**
   - عدّل اسم المستخدم/كلمة مرور MySQL (افتراضي XAMPP غالبًا `root` بدون كلمة مرور)

4. تأكد أن **mod_rewrite** مفعّل في Apache (XAMPP عادة مفعّل).

## تجربة سريعة

- فحص الصحة:  
  `http://localhost/api/health`  
  أو إذا لم يعمل الـrewrite:  
  `http://localhost/api/index.php?r=health`

## ملاحظة عن `RewriteBase`

في ملف `.htaccess` القيمة الافتراضية:

`RewriteBase /api/`

إذا وضعت المجلد باسم آخر (مثلاً `vewo-api`) غيّرها إلى:

`RewriteBase /vewo-api/`

## Flutter

استخدم عنوان السيرفر العام بدل `localhost` عند البناء على الهاتف، مثلاً:

`http://31.57.156.84/api/health`

(مع فتح المنفذ 80 في الجدار الناري وربط Apache ليستمع على الشبكة إن لزم)

## إعدادات التطبيق وإعلانات الرئيسية

- **`GET app/bootstrap`** — بدون مصادقة: يعيد `support_phone` (لزر الاتصال في التطبيق) و`promotions` (سلايدر الإعلانات النشطة).
- **`GET admin/promotions`** — يتطلب الهيدر: `Authorization: Bearer <token>` حيث `token` يُعاد من **`auth/admin/login`**.
- **`POST admin/promotions`** — نفس الهيدر، جسم JSON:  
  `{ "title", "subtitle", "image_url", "link_type": "none"|"property"|"url", "link_target", "sort_order" }`
- **`DELETE admin/promotions?id=<uuid>`** — نفس الهيدر.

في `config.php` أضف المفتاح **`support_phone`** (انظر `config.example.php`).  
إن كانت قاعدتك قديمة، نفّذ أيضاً: `backend/db/patch_home_promotions_mysql.sql`.

## تسجيل الدخول وإنشاء حساب (JSON)

- **تسجيل**: `POST /api/index.php?r=auth/register`  
  جسم JSON: `{ "full_name": "...", "phone": "07XXXXXXXXX", "password": "....", "role": "customer" | "office" }`

- **دخول**: `POST /api/index.php?r=auth/login`  
  جسم JSON: `{ "phone": "07XXXXXXXXX", "password": "...." }`

- **دخول لوحة الأدمن فقط** (دور `admin`): `POST /api/index.php?r=auth/admin/login`  
  نفس جسم JSON كأعلاه. إن لم يكن المستخدم `admin` تُرجع `403`.

الاستجابة الناجحة تحتوي `ok: true` و`user` (بدون كلمة المرور).

## تطبيق Flutter

شغّل التطبيق مع تعريف عنوان الـAPI، مثلاً:

`flutter run --dart-define=VEWO_API_BASE=http://10.0.2.2/api`

(محاكي أندرويد → جهازك الذي يشغّل XAMPP؛ على جهاز حقيقي استخدم IP الشبكة نفسه في المثال أعلاه.)
