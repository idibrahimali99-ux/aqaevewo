<?php
declare(strict_types=1);

/**
 * Single source of truth for the Web Town admin dashboard.
 * It mirrors vewo_admin sections only; do not add items here unless they exist in vewo_admin.
 */
function admin_sections(): array
{
    return [
        'overview' => [
            'label' => 'نظرة عامة', 'icon' => 'OV', 'group' => 'الرئيسية', 'permission' => null,
            'endpoint' => 'admin/stats', 'query' => [],
            'description' => 'إحصاءات النظام، آخر الأنشطة، الاختصارات، والتنبيهات.',
            'tabs' => ['إحصاءات', 'آخر الأنشطة', 'اختصارات'],
            'operations' => [
                'cancel_urgent_sale' => ['label' => 'إلغاء البيع العاجل', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['property_id' => 'معرّف العقار'], 'fixed' => ['action' => 'cancel_urgent_sale']],
            ],
        ],
        'promotions' => [
            'label' => 'إعلانات الرئيسية', 'icon' => 'PR', 'group' => 'المحتوى', 'permission' => 'promotions',
            'endpoint' => 'admin/promotions', 'description' => 'إضافة وتعديل وحذف إعلانات الرئيسية ورفع صورة أو فيديو.',
            'tabs' => ['القائمة', 'إضافة/تعديل', 'حذف', 'رفع ملف'],
            'operations' => [
                'create' => ['label' => 'إضافة إعلان', 'endpoint' => 'admin/promotions', 'method' => 'POST', 'fields' => ['title' => 'العنوان', 'subtitle' => 'الوصف', 'image_url' => 'رابط الصورة', 'slot' => 'home/search', 'display_mode' => 'popup/slider/both', 'popup_duration_sec' => 'مدة النافذة', 'sort_order' => 'الترتيب', 'link_type' => 'none/property/url', 'link_target' => 'هدف الرابط']],
                'update' => ['label' => 'تعديل إعلان', 'endpoint' => 'admin/promotions', 'method' => 'POST', 'fields' => ['id' => 'معرّف الإعلان', 'title' => 'العنوان', 'subtitle' => 'الوصف', 'image_url' => 'رابط الصورة', 'slot' => 'home/search', 'display_mode' => 'popup/slider/both', 'popup_duration_sec' => 'مدة النافذة', 'sort_order' => 'الترتيب', 'link_type' => 'none/property/url', 'link_target' => 'هدف الرابط'], 'fixed' => ['action' => 'update']],
                'delete' => ['label' => 'حذف إعلان', 'endpoint' => 'admin/promotions', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف الإعلان']],
                'upload' => ['label' => 'رفع صورة/فيديو', 'endpoint' => 'admin/upload', 'method' => 'UPLOAD', 'fields' => []],
            ],
        ],
        'news' => [
            'label' => 'أخبار العقارات', 'icon' => 'NW', 'group' => 'المحتوى', 'permission' => 'news',
            'endpoint' => 'admin/property-news', 'description' => 'إدارة أخبار العقارات.',
            'tabs' => ['القائمة', 'إضافة/تعديل', 'حذف', 'رفع صورة'],
            'operations' => [
                'create' => ['label' => 'إضافة خبر', 'endpoint' => 'admin/property-news', 'method' => 'POST', 'fields' => ['title' => 'العنوان', 'image_url' => 'رابط الصورة', 'body' => 'المحتوى', 'sort_order' => 'الترتيب', 'notify_all' => '1 لإشعار الجميع'], 'fixed' => []],
                'update' => ['label' => 'تعديل خبر', 'endpoint' => 'admin/property-news', 'method' => 'POST', 'fields' => ['id' => 'معرّف الخبر', 'title' => 'العنوان', 'image_url' => 'رابط الصورة', 'body' => 'المحتوى', 'sort_order' => 'الترتيب'], 'fixed' => ['action' => 'update']],
                'delete' => ['label' => 'حذف خبر', 'endpoint' => 'admin/property-news', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف الخبر']],
                'upload' => ['label' => 'رفع صورة', 'endpoint' => 'admin/upload', 'method' => 'UPLOAD', 'fields' => []],
            ],
        ],
        'offices' => [
            'label' => 'مكاتب', 'icon' => 'OF', 'group' => 'السوق', 'permission' => 'offices',
            'endpoint' => 'admin/offices', 'query' => ['scope' => 'pending'], 'description' => 'طلبات الموافقة والتوثيق للمكاتب.',
            'tabs' => ['بانتظار الموافقة', 'معتمدون وتوثيق', 'تفاصيل'],
            'operations' => [
                'approve' => ['label' => 'موافقة مكتب', 'endpoint' => 'admin/offices', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم'], 'fixed' => ['action' => 'approve']],
                'set_verified' => ['label' => 'توثيق/إلغاء توثيق', 'endpoint' => 'admin/offices', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'verified' => '1 أو 0'], 'fixed' => ['action' => 'set_verified']],
            ],
        ],
        'governorates' => [
            'label' => 'محافظات', 'icon' => 'GV', 'group' => 'الجغرافيا', 'permission' => 'settings',
            'endpoint' => 'admin/governorates', 'description' => 'إدارة المحافظات والأقضية والنواحي.',
            'tabs' => ['محافظات', 'أقضية/نواحي'],
            'operations' => [
                'create' => ['label' => 'إنشاء محافظة', 'endpoint' => 'admin/governorates', 'method' => 'POST', 'fields' => ['name' => 'الاسم', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0'], 'fixed' => ['action' => 'create']],
                'upsert' => ['label' => 'إضافة/تعديل محافظة', 'endpoint' => 'admin/governorates', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'name' => 'الاسم', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0']],
                'delete' => ['label' => 'حذف محافظة', 'endpoint' => 'admin/governorates', 'method' => 'POST', 'fields' => ['id' => 'معرّف المحافظة'], 'fixed' => ['action' => 'delete']],
                'district_upsert' => ['label' => 'إضافة/تعديل قضاء/ناحية', 'endpoint' => 'admin/districts', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'governorate_id' => 'معرّف المحافظة', 'name' => 'الاسم', 'kind' => 'qada/nahi', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0']],
                'district_delete' => ['label' => 'حذف قضاء/ناحية', 'endpoint' => 'admin/districts', 'method' => 'POST', 'fields' => ['id' => 'معرّف القضاء/الناحية'], 'fixed' => ['action' => 'delete']],
            ],
        ],
        'parcels' => [
            'label' => 'مقاطعات', 'icon' => 'PA', 'group' => 'الجغرافيا', 'permission' => 'parcels',
            'endpoint' => 'admin/parcels', 'description' => 'قائمة المقاطعات مع الإضافة والتعديل والحذف.',
            'tabs' => ['القائمة', 'إضافة/تعديل', 'حذف'],
            'operations' => [
                'upsert' => ['label' => 'إضافة/تعديل مقاطعة', 'endpoint' => 'admin/parcels', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'governorate_id' => 'المحافظة', 'district_id' => 'القضاء', 'name' => 'الاسم', 'parcel_no' => 'رقم المقاطعة', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0'], 'fixed' => ['action' => 'upsert']],
                'delete' => ['label' => 'حذف مقاطعة', 'endpoint' => 'admin/parcels', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف المقاطعة']],
            ],
        ],
        'compounds' => [
            'label' => 'مجمعات سكنية', 'icon' => 'CO', 'group' => 'الجغرافيا', 'permission' => 'parcels',
            'endpoint' => 'admin/compounds', 'description' => 'إدارة المجمعات السكنية وصورها.',
            'tabs' => ['القائمة', 'إضافة/تعديل', 'حذف', 'رفع صورة'],
            'operations' => [
                'upsert' => ['label' => 'إضافة/تعديل مجمع', 'endpoint' => 'admin/compounds', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'governorate_id' => 'المحافظة', 'district_id' => 'القضاء', 'name' => 'الاسم', 'compound_name' => 'اسم المجمع', 'governorate' => 'المحافظة', 'photo_url' => 'رابط الصورة', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0'], 'fixed' => ['action' => 'upsert']],
                'delete' => ['label' => 'حذف مجمع', 'endpoint' => 'admin/compounds', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف المجمع']],
                'upload' => ['label' => 'رفع صورة مجمع', 'endpoint' => 'admin/upload', 'method' => 'UPLOAD', 'fields' => []],
            ],
        ],
        'properties' => [
            'label' => 'منشورات', 'icon' => 'PO', 'group' => 'السوق', 'permission' => 'properties',
            'endpoint' => 'admin/properties', 'query' => ['status' => 'pending'], 'description' => 'مراجعة ونشر ورفض وتعديل وحذف وتعليم البيع وجدولة التفاعل.',
            'tabs' => ['مراجعة', 'لم يبع', 'تم البيع', 'تفاعل'],
            'operations' => [
                'approve' => ['label' => 'موافقة ونشر', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور'], 'fixed' => ['action' => 'approve']],
                'reject' => ['label' => 'رفض مع ملاحظة', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور', 'reject_note' => 'سبب الرفض', 'resubmission_allowed' => '1 أو 0'], 'fixed' => ['action' => 'reject']],
                'mark_sold' => ['label' => 'تعليم تم البيع', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور'], 'fixed' => ['action' => 'mark_sold']],
                'unmark_sold' => ['label' => 'إلغاء تم البيع', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور'], 'fixed' => ['action' => 'unmark_sold']],
                'urgent_sale' => ['label' => 'تفعيل البيع العاجل', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور', 'days' => '1-365', 'notify_all' => '1 لإشعار الجميع'], 'fixed' => ['action' => 'urgent_sale']],
                'cancel_urgent_sale' => ['label' => 'إلغاء البيع العاجل', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور'], 'fixed' => ['action' => 'cancel_urgent_sale']],
                'update' => ['label' => 'تعديل منشور', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور', 'title' => 'العنوان', 'governorate' => 'المحافظة', 'address_line' => 'العنوان التفصيلي', 'purpose' => 'sale/rent', 'price_iqd' => 'السعر', 'area_sqm' => 'المساحة', 'description' => 'الوصف', 'requires_review' => '1 أو 0'], 'fixed' => ['action' => 'update']],
                'delete' => ['label' => 'حذف نهائي', 'endpoint' => 'admin/properties', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف المنشور']],
                'engagement' => ['label' => 'جدولة تفاعل', 'endpoint' => 'admin/engagement', 'method' => 'POST', 'permission' => 'engagement', 'fields' => ['target_kind' => 'property', 'target_public_no' => 'رقم المنشور', 'views_per_hour' => 'مشاهدات/ساعة', 'likes_per_hour' => 'لايكات/ساعة', 'hours' => 'المدة بالساعات']],
            ],
        ],
        'reels' => [
            'label' => 'ريلز', 'icon' => 'RE', 'group' => 'السوق', 'permission' => ['reels', 'properties'],
            'endpoint' => 'admin/reels', 'query' => ['status' => 'pending'], 'description' => 'مراجعة الريلز ومعاينتها واعتمادها أو رفضها أو حذفها وجدولة التفاعل.',
            'tabs' => ['مراجعة', 'منشورة', 'مرفوضة', 'الأكثر شعبية'],
            'operations' => [
                'approve' => ['label' => 'موافقة ريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل'], 'fixed' => ['action' => 'approve']],
                'reject' => ['label' => 'رفض ريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل', 'reject_note' => 'سبب الرفض', 'resubmission_allowed' => '1 للسماح بالتعديل'], 'fixed' => ['action' => 'reject']],
                'update' => ['label' => 'تعديل ريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل', 'caption' => 'الوصف'], 'fixed' => ['action' => 'update']],
                'mark_sold' => ['label' => 'تم البيع للريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل'], 'fixed' => ['action' => 'mark_sold']],
                'unmark_sold' => ['label' => 'إلغاء تم البيع للريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل'], 'fixed' => ['action' => 'unmark_sold']],
                'delete' => ['label' => 'حذف ريل', 'endpoint' => 'admin/reels', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف الريل']],
                'engagement' => ['label' => 'جدولة تفاعل', 'endpoint' => 'admin/engagement', 'method' => 'POST', 'permission' => 'engagement', 'fields' => ['target_kind' => 'reel', 'target_public_no' => 'رقم الريل', 'views_per_hour' => 'مشاهدات/ساعة', 'likes_per_hour' => 'لايكات/ساعة', 'hours' => 'المدة بالساعات']],
            ],
        ],
        'property_requests' => [
            'label' => 'طلبات العقار', 'icon' => 'PR', 'group' => 'السوق', 'permission' => 'properties',
            'endpoint' => 'admin/property-requests', 'description' => 'طلبات ابحث عن عقار مع تحديث الحالة.',
            'tabs' => ['الكل', 'انتظار', 'تنفيذ', 'مغلق'],
            'operations' => [
                'status' => ['label' => 'تحديث حالة', 'endpoint' => 'admin/property-requests', 'method' => 'POST', 'fields' => ['id' => 'معرّف الطلب', 'status' => 'pending/in_progress/closed']],
            ],
        ],
        'chats' => [
            'label' => 'محادثات', 'icon' => 'CH', 'group' => 'التواصل', 'permission' => 'chats',
            'endpoint' => 'chat/threads', 'description' => 'قائمة المحادثات وغرفة الرسائل والإرسال وتعليم القراءة.',
            'tabs' => ['كل المحادثات', 'غير مقروءة', 'غرفة محادثة'],
            'operations' => [
                'send' => ['label' => 'إرسال رسالة', 'endpoint' => 'chat/messages', 'method' => 'POST', 'fields' => ['thread_id' => 'معرّف المحادثة', 'body' => 'نص الرسالة', 'visibility' => 'all/customer_only/office_only']],
                'read' => ['label' => 'تعليم كمقروء', 'endpoint' => 'chat/thread/read', 'method' => 'POST', 'fields' => ['thread_id' => 'معرّف المحادثة']],
                'upload' => ['label' => 'رفع ملف محادثة', 'endpoint' => 'chat/upload', 'method' => 'UPLOAD', 'fields' => []],
            ],
        ],
        'chat_room' => [
            'label' => 'غرفة محادثة', 'icon' => 'CR', 'group' => 'التواصل', 'permission' => 'chats',
            'endpoint' => 'chat/messages', 'description' => 'الشاشة الفرعية لغرفة المحادثة: عرض الرسائل، إرسال، وتعليم القراءة.',
            'tabs' => ['رسائل', 'إرسال', 'تعليم قراءة', 'رفع ملف'],
            'operations' => [
                'send' => ['label' => 'إرسال رسالة', 'endpoint' => 'chat/messages', 'method' => 'POST', 'fields' => ['thread_id' => 'معرّف المحادثة', 'body' => 'نص الرسالة', 'visibility' => 'all/customer_only/office_only']],
                'read' => ['label' => 'تعليم كمقروء', 'endpoint' => 'chat/thread/read', 'method' => 'POST', 'fields' => ['thread_id' => 'معرّف المحادثة']],
                'upload' => ['label' => 'رفع ملف محادثة', 'endpoint' => 'chat/upload', 'method' => 'UPLOAD', 'fields' => []],
            ],
        ],
        'users' => [
            'label' => 'مستخدمون', 'icon' => 'US', 'group' => 'المستخدمون والربح', 'permission' => 'users',
            'endpoint' => 'admin/users', 'description' => 'الأشخاص وموظفو لوحة التحكم والمكاتب والمسوقون وإدارة الحسابات.',
            'tabs' => ['أشخاص', 'لوحة التحكم', 'مكاتب', 'مسوقون'],
            'operations' => [
                'create_customer' => ['label' => 'إنشاء زبون', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['full_name' => 'الاسم', 'phone' => 'الهاتف', 'email' => 'البريد', 'password' => 'كلمة المرور'], 'fixed' => ['action' => 'create_customer']],
                'create_office' => ['label' => 'إنشاء مكتب/مسوق', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['full_name' => 'الاسم', 'phone' => 'الهاتف', 'email' => 'البريد', 'password' => 'كلمة المرور', 'office_name' => 'اسم المكتب', 'office_address' => 'العنوان', 'office_license_no' => 'الإجازة', 'is_marketer' => '1 للمسوق'], 'fixed' => ['action' => 'create_office']],
                'create_staff' => ['label' => 'إنشاء موظف', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['full_name' => 'الاسم', 'phone' => 'الهاتف', 'email' => 'البريد', 'password' => 'كلمة المرور', 'permissions' => 'permissions مفصولة بفواصل'], 'fixed' => ['action' => 'create_staff']],
                'create_admin' => ['label' => 'إنشاء أدمن', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['full_name' => 'الاسم', 'phone' => 'الهاتف', 'email' => 'البريد', 'password' => 'كلمة المرور'], 'fixed' => ['action' => 'create_admin']],
                'update_user' => ['label' => 'تعديل مستخدم', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'full_name' => 'الاسم', 'email' => 'البريد', 'office_name' => 'اسم المكتب', 'permissions' => 'صلاحيات الموظف'], 'fixed' => ['action' => 'update_user']],
                'active' => ['label' => 'تفعيل/تعطيل', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'is_active' => '1 أو 0']],
                'reset_password' => ['label' => 'تغيير كلمة مرور', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'password' => 'كلمة المرور الجديدة'], 'fixed' => ['action' => 'reset_password']],
                'delete_user' => ['label' => 'تعطيل حساب', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم'], 'fixed' => ['action' => 'delete_user']],
                'delete_user_permanent' => ['label' => 'حذف جذري', 'endpoint' => 'admin/users', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'pin' => 'PIN'], 'fixed' => ['action' => 'delete_user_permanent']],
            ],
        ],
        'user_profile' => [
            'label' => 'ملف مستخدم', 'icon' => 'UP', 'group' => 'المستخدمون والربح', 'permission' => 'users',
            'endpoint' => 'admin/user', 'description' => 'عرض ملف مستخدم.',
            'tabs' => ['بيانات المستخدم', 'منشورات', 'محادثات'],
            'operations' => [],
        ],
        'marketers' => [
            'label' => 'مسوقون', 'icon' => 'MK', 'group' => 'المستخدمون والربح', 'permission' => 'users',
            'endpoint' => 'admin/marketers', 'description' => 'قائمة المسوقين والباقات والمتابعين التركيبيين.',
            'tabs' => ['المسوقون', 'الباقات', 'متابعون'],
            'operations' => [
                'assign_package' => ['label' => 'تعديل باقة/رصيد', 'endpoint' => 'admin/assign-package', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المسوق', 'posting_package_id' => 'معرّف الباقة', 'posting_listings_remaining' => 'الرصيد']],
                'follow_boost' => ['label' => 'زيادة متابعين تركيبية', 'endpoint' => 'admin/follow/boost', 'method' => 'POST', 'permission' => 'engagement', 'fields' => ['target_kind' => 'office/compound/parcel', 'target_id' => 'معرّف الهدف', 'amount' => 'العدد']],
            ],
        ],
        'posting_packages' => [
            'label' => 'باقات النشر', 'icon' => 'PK', 'group' => 'المستخدمون والربح', 'permission' => 'users',
            'endpoint' => 'admin/posting-packages', 'description' => 'باقات المكاتب والمسوقين وتعيين الباقات.',
            'tabs' => ['باقات المكاتب', 'باقات المسوقين', 'تعيين باقة'],
            'operations' => [
                'upsert' => ['label' => 'إضافة/تعديل باقة', 'endpoint' => 'admin/posting-packages', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'name' => 'اسم الباقة', 'listings_limit' => 'الحد', 'is_unlimited' => '1 أو 0', 'applies_to' => 'office/marketer', 'is_active' => '1 أو 0']],
                'delete' => ['label' => 'حذف باقة', 'endpoint' => 'admin/posting-packages', 'method' => 'POST', 'fields' => ['id' => 'معرّف الباقة'], 'fixed' => ['action' => 'delete']],
                'assign' => ['label' => 'تعيين باقة', 'endpoint' => 'admin/assign-package', 'method' => 'POST', 'fields' => ['user_id' => 'معرّف المستخدم', 'posting_package_id' => 'معرّف الباقة', 'posting_listings_remaining' => 'الرصيد']],
            ],
        ],
        'reports' => [
            'label' => 'تقارير', 'icon' => 'RP', 'group' => 'التحليلات', 'permission' => null,
            'endpoint' => 'admin/reports', 'description' => 'تقارير الفترة وتصدير CSV.',
            'tabs' => ['فترة', 'توزيع الأدوار', 'تصدير CSV'],
            'operations' => [],
        ],
        'notifications' => [
            'label' => 'إشعارات', 'icon' => 'NT', 'group' => 'التواصل', 'permission' => null,
            'endpoint' => 'admin/stats', 'description' => 'مركز إشعارات مبني على عدادات admin/stats: محادثات، منشورات، ومكاتب معلقة.',
            'tabs' => ['عدادات', 'روابط سريعة'],
            'operations' => [],
        ],
        'settings' => [
            'label' => 'إعدادات', 'icon' => 'ST', 'group' => 'النظام', 'permission' => 'settings',
            'endpoint' => 'health', 'description' => 'فحص API، إشعارات فورية، اختبار FCM، أقسام الرئيسية، وإجراءات المنطقة الخطرة.',
            'tabs' => ['Health', 'Broadcast', 'FCM', 'Home Sections', 'Danger Zone'],
            'operations' => [
                'broadcast' => ['label' => 'إرسال إشعار فوري', 'endpoint' => 'admin/broadcast', 'method' => 'POST', 'fields' => ['target' => 'users/admins/all', 'title' => 'العنوان', 'body' => 'المحتوى', 'kind' => 'broadcast/reminder']],
                'fcm_test' => ['label' => 'اختبار إشعار FCM', 'endpoint' => 'admin/fcm/test', 'method' => 'POST', 'fields' => []],
                'home_section' => ['label' => 'تعديل أيقونة قسم رئيسية', 'endpoint' => 'admin/home-sections', 'method' => 'POST', 'fields' => ['section_key' => 'المفتاح', 'label' => 'التسمية', 'route_target' => 'المسار', 'icon_name' => 'الأيقونة', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0']],
                'telegram_save' => ['label' => 'حفظ تيليغرام', 'endpoint' => 'admin/telegram', 'method' => 'POST', 'fields' => ['bot_token' => 'توكن البوت', 'chat_id' => 'معرّف المحادثة'], 'fixed' => ['action' => 'save']],
                'app_update_save' => ['label' => 'حفظ تحديث التطبيق', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'keep_empty' => true, 'fields' => ['enabled' => 'تفعيل', 'latest_version' => 'أحدث إصدار', 'min_version' => 'الحد الأدنى', 'min_build' => 'رقم البناء', 'android_store_url' => 'رابط أندرويد', 'ios_store_url' => 'رابط App Store', 'title' => 'عنوان التنبيه', 'message' => 'نص التنبيه', 'android_enabled' => 'تفعيل أندرويد', 'ios_enabled' => 'تفعيل iOS', 'android_latest_version' => 'إصدار أندرويد', 'android_min_version' => 'حد أندرويد', 'android_min_build' => 'بناء أندرويد', 'ios_latest_version' => 'إصدار iOS', 'ios_min_version' => 'حد iOS', 'ios_min_build' => 'بناء iOS', 'platform' => 'المنصة']],
                'app_update_save_android' => ['label' => 'حفظ تحديث أندرويد', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'keep_empty' => true, 'fixed' => ['platform' => 'android'], 'fields' => ['android_enabled' => 'تفعيل أندرويد', 'android_latest_version' => 'أحدث إصدار', 'android_min_version' => 'الحد الأدنى', 'android_min_build' => 'رقم البناء', 'android_store_url' => 'رابط أندرويد', 'title' => 'عنوان التنبيه', 'message' => 'نص التنبيه']],
                'app_update_save_ios' => ['label' => 'حفظ تحديث App Store', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'keep_empty' => true, 'fixed' => ['platform' => 'ios'], 'fields' => ['ios_enabled' => 'تفعيل iOS', 'ios_latest_version' => 'أحدث إصدار', 'ios_min_version' => 'الحد الأدنى', 'ios_min_build' => 'رقم البناء', 'ios_store_url' => 'رابط App Store', 'title' => 'عنوان التنبيه', 'message' => 'نص التنبيه']],
                'app_update_clear' => ['label' => 'إيقاف تحديث المنصتين', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'clear', 'platform' => 'both']],
                'app_update_clear_android' => ['label' => 'إيقاف تحديث أندرويد', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'clear_android']],
                'app_update_clear_ios' => ['label' => 'إيقاف تحديث App Store', 'endpoint' => 'admin/app-update', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'clear_ios']],
                'telegram_test' => ['label' => 'اختبار تيليغرام', 'endpoint' => 'admin/telegram', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'test']],
                'repair_web' => ['label' => 'إصلاح Nginx/PHP', 'endpoint' => 'admin/telegram', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'repair_web']],
                'backup_now' => ['label' => 'نسخ احتياطي الآن', 'endpoint' => 'admin/telegram', 'method' => 'POST', 'fields' => [], 'fixed' => ['action' => 'backup_now']],
                'maintenance_on' => ['label' => 'تشغيل الصيانة', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'maintenance_on']],
                'maintenance_off' => ['label' => 'إيقاف الصيانة', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'maintenance_off']],
                'delete_all_properties' => ['label' => 'حذف كل المنشورات', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'delete_all_properties']],
                'delete_all_chats' => ['label' => 'تصفير كل المحادثات', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'delete_all_chats']],
                'delete_all_users_except_me' => ['label' => 'حذف كل المستخدمين عداي', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'delete_all_users_except_me']],
            ],
        ],
    ];
}

function admin_section(string $key): ?array
{
    $sections = admin_sections();
    return $sections[$key] ?? null;
}

function admin_can_access_section(array $section): bool
{
    $permission = $section['permission'] ?? null;
    if ($permission === null) {
        return is_admin_area_user();
    }
    if (is_array($permission)) {
        foreach ($permission as $item) {
            if (can_staff((string) $item)) {
                return true;
            }
        }
        return false;
    }
    return can_staff((string) $permission);
}

function admin_visible_sections(): array
{
    return array_filter(
        admin_sections(),
        static function (array $section, string $key): bool {
            if ($key === 'user_profile') {
                return false;
            }
            return admin_can_access_section($section);
        },
        ARRAY_FILTER_USE_BOTH
    );
}

function admin_default_section(): string
{
    foreach (admin_visible_sections() as $key => $_section) {
        return (string) $key;
    }
    return 'overview';
}

function admin_section_data(string $sectionKey, array $query = []): array
{
    require_admin_api_token();
    $section = admin_section($sectionKey);
    if ($section === null || !admin_can_access_section($section)) {
        return ['ok' => false, 'error' => 'لا تملك صلاحية الوصول لهذا القسم'];
    }
    $baseQuery = is_array($section['query'] ?? null) ? $section['query'] : [];
    $allowedQuery = [];
    foreach (['q', 'status', 'scope', 'from', 'to', 'sort', 'governorate_id', 'id', 'user_id', 'thread_id', 'tab', 'role', 'create', 'compound_id', 'property_kind'] as $key) {
        if (!isset($query[$key]) || trim((string) $query[$key]) === '') {
            continue;
        }
        if ($key === 'status' && trim((string) $query[$key]) === 'all') {
            continue;
        }
        $allowedQuery[$key] = trim((string) $query[$key]);
    }
    if ($sectionKey === 'user_profile') {
        $profileId = trim((string) ($allowedQuery['id'] ?? $allowedQuery['user_id'] ?? $query['id'] ?? $query['user_id'] ?? ''));
        if ($profileId !== '') {
            $allowedQuery['id'] = $profileId;
            $allowedQuery['user_id'] = $profileId;
        }
    }
    return api_client()->get((string) $section['endpoint'], array_merge($baseQuery, $allowedQuery), auth_token());
}

/** @return array<string,string> */
function admin_staff_permission_labels(): array
{
    return [
        'promotions' => 'إعلانات الرئيسية',
        'news' => 'أخبار العقارات',
        'offices' => 'المكاتب',
        'parcels' => 'المقاطعات والمجمعات',
        'properties' => 'المنشورات',
        'reels' => 'الريلز',
        'engagement' => 'جدولة المشاهدات',
        'chats' => 'المحادثات',
        'users' => 'المستخدمون والباقات',
        'settings' => 'الإعدادات والجغرافيا',
        'unsold' => 'إلغاء تم البيع وإرجاع المنشور',
    ];
}

function admin_image_picker(string $urlField, string $current = '', string $fileField = 'image'): string
{
    $html = '<div class="admin-image-picker">';
    $html .= '<label class="form-label small mb-1">صورة من الجهاز</label>';
    if ($current !== '') {
        $html .= '<div class="mb-2"><img src="' . e($current) . '" alt="" class="admin-upload-preview"></div>';
    }
    $html .= '<input type="file" name="' . e($fileField) . '" class="form-control form-control-sm" accept="image/jpeg,image/png,image/webp,image/gif">';
    $html .= '<input type="hidden" name="' . e($urlField) . '" value="' . e($current) . '">';
    $html .= '<div class="form-text">ارفع صورة مباشرة بدل لصق الرابط.</div></div>';

    return $html;
}

/** @return array<string,mixed> */
function admin_local_server_stats(): array
{
    if (function_exists('vewo_collect_server_stats')) {
        return vewo_collect_server_stats();
    }
    $load = function_exists('sys_getloadavg') ? sys_getloadavg() : [0, 0, 0];
    $root = DIRECTORY_SEPARATOR === '\\' ? 'C:\\' : '/';

    return [
        'ok' => true,
        'time' => date('c'),
        'timezone' => date_default_timezone_get(),
        'country' => 'العراق',
        'hostname' => php_uname('n'),
        'os' => php_uname('s') . ' ' . php_uname('r'),
        'php' => PHP_VERSION,
        'cpu_model' => php_uname('m'),
        'cpu_cores' => 1,
        'load_1' => is_array($load) ? round((float) ($load[0] ?? 0), 2) : 0,
        'cpu_usage_pct' => 0,
        'memory_total' => 0,
        'memory_used' => 0,
        'disk_total' => @disk_total_space($root) ?: 0,
        'disk_free' => @disk_free_space($root) ?: 0,
        'net_rx' => 0,
        'net_tx' => 0,
        'uptime' => 0,
    ];
}

function admin_format_bytes(int $bytes): string
{
    if ($bytes < 1024) {
        return $bytes . ' بايت';
    }
    $units = ['ك.ب', 'م.ب', 'ج.ب', 'ت.ب'];
    $v = (float) $bytes;
    foreach ($units as $u) {
        $v /= 1024;
        if ($v < 1024) {
            return round($v, 1) . ' ' . $u;
        }
    }

    return round($v / 1024, 1) . ' ت.ب';
}

function admin_operation(string $sectionKey, string $operationKey): ?array
{
    $section = admin_section($sectionKey);
    if ($section === null || !admin_can_access_section($section)) {
        return null;
    }
    $operations = $section['operations'] ?? [];
    $operation = is_array($operations) ? ($operations[$operationKey] ?? null) : null;
    if (!is_array($operation)) {
        return null;
    }
    $permission = $operation['permission'] ?? null;
    if ($permission !== null && !can_staff((string) $permission)) {
        return null;
    }
    return $operation;
}

function normalize_admin_value(string $key, string $value): mixed
{
    $value = trim($value);
    if ($value === '') {
        return null;
    }
    if (in_array($key, ['is_active', 'verified', 'resubmission_allowed', 'requires_review', 'is_unlimited', 'is_marketer', 'is_private', 'notify_all'], true)) {
        return (int) $value;
    }
    if (in_array($key, ['sort_order', 'popup_duration_sec', 'days', 'views_per_hour', 'likes_per_hour', 'hours', 'amount', 'posting_listings_remaining', 'listings_limit', 'floors_count', 'units_per_floor'], true)) {
        return is_numeric($value) ? (int) $value : $value;
    }
    if ($key === 'permissions') {
        return array_values(array_filter(array_map('trim', explode(',', $value))));
    }
    return $value;
}

function run_admin_operation(string $sectionKey, string $operationKey, array $input): array
{
    require_admin_api_token();
    $operation = admin_operation($sectionKey, $operationKey);
    if ($operation === null) {
        return ['ok' => false, 'error' => 'العملية غير متاحة أو لا تملك صلاحيتها'];
    }
    $payload = is_array($operation['fixed'] ?? null) ? $operation['fixed'] : [];
    $fields = is_array($operation['fields'] ?? null) ? $operation['fields'] : [];
    $keepEmpty = !empty($operation['keep_empty']);
    foreach (array_keys($fields) as $field) {
        if ($field === 'permissions') {
            $raw = $input['permissions'] ?? [];
            if (is_array($raw)) {
                $payload['permissions'] = array_values(array_filter(array_map('strval', $raw)));
            } elseif (is_string($raw) && $raw !== '') {
                $payload['permissions'] = array_values(array_filter(array_map('trim', explode(',', $raw))));
            }
            continue;
        }
        if (array_key_exists($field, $input)) {
            $value = normalize_admin_value((string) $field, (string) $input[$field]);
            if ($value !== null) {
                $payload[$field] = $value;
            } elseif ($keepEmpty) {
                $payload[$field] = in_array($field, ['min_build', 'latest_build', 'enabled', 'android_enabled', 'ios_enabled', 'android_min_build', 'ios_min_build', 'android_latest_build', 'ios_latest_build'], true) ? 0 : '';
            }
        }
    }
    if ($sectionKey === 'posting_packages' && $operationKey === 'upsert') {
        if (isset($payload['name']) && !isset($payload['name_ar'])) {
            $payload['name_ar'] = $payload['name'];
        }
        if (array_key_exists('listings_limit', $payload) && !array_key_exists('listing_limit', $payload)) {
            $payload['listing_limit'] = $payload['listings_limit'];
        }
        if (!empty($payload['is_unlimited'])) {
            $payload['unlimited'] = true;
        }
    }
    $endpoint = (string) $operation['endpoint'];
    $method = strtoupper((string) ($operation['method'] ?? 'POST'));
    if ($method === 'UPLOAD') {
        $file = $_FILES['file'] ?? $_FILES['image'] ?? null;
        if (!is_array($file) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            return ['ok' => false, 'error' => 'اختر ملفا صالحا للرفع'];
        }
        return api_client()->upload(
            $endpoint,
            (string) ($file['tmp_name'] ?? ''),
            (string) ($file['name'] ?? 'upload.bin'),
            auth_token()
        );
    }
    $uploadedUrl = '';
    foreach (['image', 'photo', 'file'] as $ff) {
        $file = $_FILES[$ff] ?? null;
        if (!is_array($file) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            continue;
        }
        $up = api_client()->upload(
            'admin/upload',
            (string) ($file['tmp_name'] ?? ''),
            (string) ($file['name'] ?? 'image.bin'),
            auth_token()
        );
        if (empty($up['ok']) || empty($up['public_url'])) {
            return ['ok' => false, 'error' => (string) ($up['error'] ?? 'فشل رفع الصورة')];
        }
        $uploadedUrl = (string) $up['public_url'];
        break;
    }
    if ($uploadedUrl !== '') {
        if (isset($fields['photo_url']) || $sectionKey === 'compounds') {
            $payload['photo_url'] = $uploadedUrl;
        }
        if (isset($fields['image_url'])) {
            $payload['image_url'] = $uploadedUrl;
        }
    }
    if ($sectionKey === 'compounds' && $operationKey === 'upsert') {
        if (empty($payload['compound_name'])) {
            $payload['compound_name'] = trim((string) ($input['name'] ?? $input['compound_name'] ?? ''));
        }
        if (empty($payload['governorate']) && !empty($input['governorate_id'])) {
            $opts = admin_governorate_options();
            $gid = (string) $input['governorate_id'];
            $payload['governorate'] = $opts[$gid] ?? '';
        }
        if (empty($payload['photo_url']) && !empty($input['photo_url'])) {
            $payload['photo_url'] = trim((string) $input['photo_url']);
        }
        if (!isset($payload['district_id']) && isset($input['district_id'])) {
            $payload['district_id'] = trim((string) $input['district_id']);
        }
    }
    if ($method === 'DELETE') {
        return api_client()->delete($endpoint, $payload, auth_token());
    }
    return api_client()->post($endpoint, $payload, auth_token());
}

function admin_sort_rows(array $rows, string $sort, callable $labelFn): array
{
    $rows = array_values(array_filter($rows, static fn (mixed $row): bool => is_array($row)));
    usort($rows, static function (array $a, array $b) use ($sort, $labelFn): int {
        return match ($sort) {
            'name_asc' => strcmp($labelFn($a), $labelFn($b)),
            'name_desc' => strcmp($labelFn($b), $labelFn($a)),
            'phone_asc' => strcmp((string) ($a['phone'] ?? ''), (string) ($b['phone'] ?? '')),
            'views_desc' => ((int) ($b['view_count'] ?? $b['views'] ?? 0)) <=> ((int) ($a['view_count'] ?? $a['views'] ?? 0)),
            'sort_order' => ((int) ($a['sort_order'] ?? 0)) <=> ((int) ($b['sort_order'] ?? 0)),
            default => strcmp((string) ($b['created_at'] ?? ''), (string) ($a['created_at'] ?? '')),
        };
    });

    return $rows;
}

function admin_office_label(array $row): string
{
    $office = trim((string) ($row['office_name'] ?? ''));

    return $office !== '' ? $office : trim((string) ($row['full_name'] ?? ''));
}

function admin_sort_select(string $sectionKey, string $current, array $options, array $preserve = []): string
{
    $html = '<select name="sort" class="form-select form-select-sm admin-sort-select" onchange="this.form.submit()">';
    foreach ($options as $value => $label) {
        $selected = $current === $value ? ' selected' : '';
        $html .= '<option value="' . e($value) . '"' . $selected . '>' . e($label) . '</option>';
    }
    $html .= '</select>';

    return $html;
}

function admin_select_field(string $name, array $options, string $placeholder = '— اختر —', ?string $selected = null, bool $required = false): string
{
    $html = '<select name="' . e($name) . '" class="form-select form-select-sm"' . ($required ? ' required' : '') . '>';
    $html .= '<option value="">' . e($placeholder) . '</option>';
    foreach ($options as $value => $label) {
        $sel = ($selected !== null && (string) $selected === (string) $value) ? ' selected' : '';
        $html .= '<option value="' . e((string) $value) . '"' . $sel . '>' . e((string) $label) . '</option>';
    }
    $html .= '</select>';

    return $html;
}

/** @return list<array<string,mixed>> */
function admin_governorates_list(): array
{
    static $cache = null;
    if (is_array($cache)) {
        return $cache;
    }
    require_admin_api_token();
    $resp = api_client()->get('admin/governorates', [], auth_token());
    $cache = admin_items_from_response($resp);

    return $cache;
}

/** @return array<string,string> */
function admin_governorate_options(): array
{
    $options = [];
    foreach (admin_governorates_list() as $gov) {
        if (!is_array($gov)) {
            continue;
        }
        $id = (string) ($gov['id'] ?? '');
        if ($id === '') {
            continue;
        }
        $options[$id] = (string) ($gov['name'] ?? $id);
    }

    return $options;
}

/** @return list<array<string,mixed>> */
function admin_districts_list(?string $governorateId = null): array
{
    require_admin_api_token();
    if ($governorateId !== null && $governorateId !== '') {
        $resp = api_client()->get('admin/districts', ['governorate_id' => $governorateId], auth_token());

        return admin_items_from_response($resp);
    }
    $all = [];
    foreach (admin_governorates_list() as $gov) {
        if (!is_array($gov)) {
            continue;
        }
        $gid = (string) ($gov['id'] ?? '');
        if ($gid === '') {
            continue;
        }
        foreach (admin_districts_list($gid) as $district) {
            if (!is_array($district)) {
                continue;
            }
            $district['governorate_name'] = (string) ($gov['name'] ?? '');
            $all[] = $district;
        }
    }

    return $all;
}

/** @return array<string,string> */
function admin_district_options(?string $governorateId = null): array
{
    $options = [];
    foreach (admin_districts_list($governorateId) as $district) {
        if (!is_array($district)) {
            continue;
        }
        $id = (string) ($district['id'] ?? '');
        if ($id === '') {
            continue;
        }
        $prefix = trim((string) ($district['governorate_name'] ?? ''));
        $name = (string) ($district['name'] ?? $id);
        $options[$id] = $prefix !== '' ? $prefix . ' · ' . $name : $name;
    }

    return $options;
}

/** @return array<string,string> */
function admin_users_options(string $role = ''): array
{
    require_admin_api_token();
    $resp = api_client()->get('admin/users', [], auth_token());
    $items = admin_items_from_response($resp);
    $options = [];
    foreach ($items as $row) {
        if (!is_array($row)) {
            continue;
        }
        $userRole = (string) ($row['role'] ?? '');
        if ($role === 'marketer' && !($userRole === 'office' && !empty($row['is_marketer']))) {
            continue;
        }
        if ($role === 'office' && !($userRole === 'office' && empty($row['is_marketer']))) {
            continue;
        }
        if (in_array($role, ['customer', 'staff', 'admin'], true) && $userRole !== $role) {
            continue;
        }
        $id = (string) ($row['id'] ?? '');
        if ($id === '') {
            continue;
        }
        $label = trim((string) ($row['full_name'] ?? 'مستخدم'));
        $phone = trim((string) ($row['phone'] ?? ''));
        if ($phone !== '') {
            $label .= ' · ' . $phone;
        }
        if (!empty($row['office_name'])) {
            $label .= ' (' . (string) $row['office_name'] . ')';
        }
        $options[$id] = $label;
    }

    return $options;
}

function admin_posting_quota_summary(array $row): string
{
    $unlimited = !empty($row['posting_trial_unlimited']) || !empty($row['posting_is_unlimited']);
    $pkg = trim((string) ($row['posting_package_name'] ?? $row['name'] ?? $row['name_ar'] ?? ''));
    $remaining = $row['posting_listings_remaining'] ?? null;
    $published = (int) ($row['published_count'] ?? 0);
    $reels = (int) ($row['reels_count'] ?? 0);
    $limit = $row['posting_package_limit'] ?? $row['listings_limit'] ?? $row['listing_limit'] ?? null;
    $used = $row['used_count'] ?? null;
    $parts = [];
    if ($pkg !== '') {
        $parts[] = $pkg;
    }
    if ($unlimited) {
        $parts[] = 'بلا حدود';
        $parts[] = 'نُشر ' . compact_number($published);
    } else {
        $parts[] = 'متبقي ' . compact_number($remaining ?? 0);
        $limitTxt = ($limit === null || $limit === '') ? '' : ' من ' . compact_number($limit);
        $parts[] = 'نُشر ' . compact_number($published) . $limitTxt;
        if ($used !== null && $used !== '') {
            $parts[] = 'مستخدم ' . compact_number($used);
        }
    }
    if ($reels > 0) {
        $parts[] = 'ريلز ' . compact_number($reels);
    }
    $exp = trim((string) ($row['posting_subscription_expires_at'] ?? ''));
    if ($exp !== '') {
        $parts[] = 'ينتهي ' . explode(' ', $exp)[0];
    }

    return $parts === [] ? '—' : implode(' · ', $parts);
}

function admin_text(mixed $value, string $fallback = ''): string
{
    if ($value === null || is_array($value) || is_object($value)) {
        return $fallback;
    }

    return trim((string) $value);
}

function admin_role_label(mixed $role, mixed $isMarketer = false): string
{
    $r = strtolower(admin_text($role));
    $marketer = $isMarketer === true || $isMarketer === 1 || $isMarketer === '1';
    return match (true) {
        $r === 'admin' => 'مسؤول',
        $r === 'staff' => 'موظف',
        $r === 'office' && $marketer => 'مسوق',
        $r === 'office' => 'مكتب',
        $r === 'customer' => 'زبون',
        $r === '' => '—',
        default => $r,
    };
}

function admin_media_url(mixed $url): string
{
    $url = admin_text($url);
    if ($url === '' || strcasecmp($url, 'null') === 0) {
        return asset_url('images/placeholder-property.svg');
    }
    if (preg_match('#^https?://#i', $url) === 1 || str_starts_with($url, 'data:')) {
        return $url;
    }
    if (str_starts_with($url, '//')) {
        return 'https:' . $url;
    }
    $hint = rtrim((string) app_config('api_base_hint', 'http://212.224.86.115/api/index.php'), '/');
    $public = preg_replace('#/index\.php$#i', '', $hint) ?: $hint;
    if (str_starts_with($url, '/uploads') || str_starts_with($url, 'uploads/')) {
        return rtrim($public, '/') . '/' . ltrim($url, '/');
    }
    if (str_starts_with($url, '/')) {
        return $url;
    }

    return rtrim($public, '/') . '/' . ltrim($url, '/');
}

function admin_user_profile_url(string $userId): string
{
    $userId = trim($userId);
    if ($userId === '') {
        return url('/admin/users');
    }

    return url('/admin/users', ['profile' => $userId]);
}

function admin_public_no_label(mixed $raw): string
{
    $s = trim((string) $raw);
    if ($s === '' || strcasecmp($s, 'null') === 0) {
        return '';
    }
    if (preg_match('/(\d{5,12})/', $s, $m) === 1) {
        return $m[1];
    }
    if (strlen($s) > 14) {
        return '';
    }

    return $s;
}

function admin_flag_on(mixed $value, bool $missingMeansOn = true): bool
{
    if ($value === null || $value === '') {
        return $missingMeansOn;
    }
    if (is_bool($value)) {
        return $value;
    }
    if (is_int($value) || is_float($value)) {
        return (int) $value !== 0;
    }
    $s = strtolower(trim((string) $value));
    if ($s === '0' || $s === 'false' || $s === 'off' || $s === 'no') {
        return false;
    }
    if ($s === '1' || $s === 'true' || $s === 'yes' || $s === 'on') {
        return true;
    }
    if ($value === "\x01") {
        return true;
    }
    if ($value === "\0" || $value === "\x00") {
        return false;
    }

    return (bool) $value;
}

function admin_items_from_response(array $response): array
{
    foreach (['items', 'data', 'rows', 'threads', 'messages', 'users', 'promotions', 'news'] as $key) {
        if (!isset($response[$key]) || !is_array($response[$key])) {
            continue;
        }
        $items = $response[$key];
        if (!array_is_list($items)) {
            foreach (['items', 'data', 'rows', 'users'] as $nestedKey) {
                if (isset($items[$nestedKey]) && is_array($items[$nestedKey])) {
                    $items = $items[$nestedKey];
                    break;
                }
            }
        }
        return array_values(array_filter($items, static fn (mixed $row): bool => is_array($row)));
    }
    if (array_is_list($response)) {
        return array_values(array_filter($response, static fn (mixed $row): bool => is_array($row)));
    }
    return [];
}

function admin_stat_value(array $stats, array $keys): mixed
{
    foreach ($keys as $key) {
        if (array_key_exists($key, $stats)) {
            return $stats[$key];
        }
    }
    return 0;
}

function admin_section_template(string $key): ?string
{
    $map = [
        'overview' => 'admin/sections/overview',
        'notifications' => 'admin/sections/notifications',
        'offices' => 'admin/sections/offices',
        'properties' => 'admin/sections/properties',
        'users' => 'admin/sections/users',
        'user_profile' => 'admin/sections/user_profile',
        'reels' => 'admin/sections/reels',
        'marketers' => 'admin/sections/marketers',
        'posting_packages' => 'admin/sections/posting_packages',
        'property_requests' => 'admin/sections/property_requests',
        'parcels' => 'admin/sections/parcels',
        'compounds' => 'admin/sections/compounds',
        'reports' => 'admin/sections/reports',
        'settings' => 'admin/sections/settings',
        'promotions' => 'admin/sections/promotions',
        'news' => 'admin/sections/news',
        'governorates' => 'admin/sections/governorates',
    ];

    return $map[$key] ?? null;
}

function admin_section_tab(string $sectionKey, string $label, array $query = [], ?string $activeValue = null): string
{
    $defaults = [
        'scope' => 'pending',
        'status' => 'pending',
        'role' => 'all',
        'tab' => 'office',
    ];
    $isActive = true;
    foreach ($query as $key => $value) {
        $current = (string) ($_GET[$key] ?? '');
        if ($current === '' && isset($defaults[$key]) && (string) $defaults[$key] === (string) $value) {
            continue;
        }
        if ($current !== (string) $value) {
            $isActive = false;
            break;
        }
    }
    $class = 'admin-tab' . ($isActive ? ' active' : '');

    return '<a class="' . $class . '" href="' . e(url('/admin/' . $sectionKey, $query)) . '">' . e($label) . '</a>';
}

/** @param array<string,mixed> $row */
function admin_activity_html(array $row): string
{
    $items = $row['activity'] ?? [];
    if (!is_array($items) || $items === []) {
        return '';
    }
    $html = '<div class="admin-activity-log small mt-2">';
    foreach (array_slice($items, 0, 6) as $item) {
        if (!is_array($item)) {
            continue;
        }
        $msg = trim((string) ($item['message'] ?? ''));
        if ($msg === '') {
            continue;
        }
        $when = trim((string) ($item['created_at'] ?? ''));
        $html .= '<div class="text-secondary">' . e($msg);
        if ($when !== '') {
            $html .= ' <span dir="ltr">' . e($when) . '</span>';
        }
        $html .= '</div>';
    }
    $html .= '</div>';

    return $html;
}

