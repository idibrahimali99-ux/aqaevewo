# vewo backend (SQL + Storage)

## مهم: PostgreSQL ≠ MariaDB / MySQL
- ملف **`db/init.sql`** مخصص لـ **PostgreSQL** (يحتوي `CREATE EXTENSION` و`UUID`…).
- إذا سيرفرك **MariaDB / MySQL** استخدم بدلًا منه: **`db/init.mysql.sql`**.

هذا المجلد يجهز لك:
- PostgreSQL قاعدة بيانات SQL
- Adminer لوحة إدارة للـSQL
- MinIO تخزين صور/فيديو (S3 compatible) للصور والريلز

## تشغيل على سيرفر RDP

### 1) تثبيت Docker Desktop (ويندوز)
ثبت Docker Desktop على السيرفر ثم أعد التشغيل إذا طلب.

### 2) تشغيل الخدمات
من داخل `backend/`:

```powershell
docker compose up -d
```

### 3) منافذ الخدمات
- PostgreSQL: `5432`
- Adminer: `8080`
- MinIO API: `9000`
- MinIO Console: `9001`

## بيانات الدخول (افتراضية للتجربة فقط)

### PostgreSQL
- DB: `vewo`
- User: `vewo`
- Password: `vewo_password_change_me`

### Adminer
افتح `http://31.57.156.84:8080`
- System: PostgreSQL
- Server: `postgres` (من داخل docker) أو `31.57.156.84` (من خارج docker)
- Username/Password/Database: كما فوق

### MinIO
افتح `http://31.57.156.84:9001`
- User: `vewo_storage_admin`
- Password: `vewo_storage_password_change_me`

## أدمن رئيسي (Seed)
تم إنشاء أدمن برقم:
- `07871456361`

وكلمة مرور افتراضية:
- `ChangeMe!123`

مهم: في `init.sql` كلمة المرور مخزنة كـ `PLAIN:...` فقط للتجربة. عند بناء الـAPI لازم تتحول إلى hash.

