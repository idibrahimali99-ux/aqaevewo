ارفع هذه الملفات إلى سيرفر لينكس:

1) index.php  →  /مسار/api/index.php
2) extend.php →  /مسار/api/lib/extend.php

مثال scp:
scp index.php root@212.224.86.115:/var/www/html/api/index.php
scp extend.php root@212.224.86.115:/var/www/html/api/lib/extend.php

ثم تحقق:
curl -s "http://212.224.86.115/api/?r=health"

ما الجديد في هذا التحديث:
- بيع عاجل + notify_all → إشعار لكل المستخدمين
- نشر خبر → إشعار فوري للجميع
- نشر إعلان رئيسية → إشعار فوري للجميع
- تشخيص FCM أقوى لـ iOS/APNs
