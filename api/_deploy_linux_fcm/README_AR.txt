تحديث API — حذف الحساب (Apple 5.1.1)
=====================================

ارفع هذه الملفات إلى سيرفر لينكس:

1) index.php  →  /var/www/aqartown/api/index.php
2) extend.php →  /var/www/aqartown/api/lib/extend.php

(عدّل المسار إن كان api عندك في مكان آخر)

--- Windows PowerShell (scp) ---
scp api\_deploy_linux_fcm\index.php root@212.224.86.115:/var/www/aqartown/api/index.php
scp api\_deploy_linux_fcm\extend.php root@212.224.86.115:/var/www/aqartown/api/lib/extend.php

--- أو من FileZilla / WinSCP ---
ارفع index.php و extend.php إلى نفس المسارات أعلاه.

--- تحقق بعد الرفع ---
curl -s "http://212.224.86.115/api/?r=health"

يجب أن يرجع ok.

--- ما الجديد ---
- POST users/delete-account — حذف الحساب نهائياً من التطبيق
- confirm: "DELETE" في body JSON
