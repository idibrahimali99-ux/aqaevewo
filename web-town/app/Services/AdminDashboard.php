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
            'description' => 'إحصاءات النظام، آخر الأنشطة، الاختصارات، والتنبيهات كما في تطبيق Admin.',
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
            'endpoint' => 'admin/property-news', 'description' => 'إدارة أخبار العقارات بنفس حقول تطبيق Admin.',
            'tabs' => ['القائمة', 'إضافة/تعديل', 'حذف', 'رفع صورة'],
            'operations' => [
                'create' => ['label' => 'إضافة خبر', 'endpoint' => 'admin/property-news', 'method' => 'POST', 'fields' => ['title' => 'العنوان', 'image_url' => 'رابط الصورة', 'body' => 'المحتوى', 'sort_order' => 'الترتيب']],
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
            'endpoint' => 'admin/governorates', 'description' => 'CRUD المحافظات وإدارة الأقضية والنواحي.',
            'tabs' => ['محافظات', 'أقضية/نواحي'],
            'operations' => [
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
                'upsert' => ['label' => 'إضافة/تعديل مجمع', 'endpoint' => 'admin/compounds', 'method' => 'POST', 'fields' => ['id' => 'اختياري للتعديل', 'governorate_id' => 'المحافظة', 'district_id' => 'القضاء', 'name' => 'الاسم', 'image_url' => 'رابط الصورة', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0'], 'fixed' => ['action' => 'upsert']],
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
                'urgent_sale' => ['label' => 'تفعيل البيع العاجل', 'endpoint' => 'admin/properties', 'method' => 'POST', 'fields' => ['id' => 'معرّف المنشور', 'days' => '1-365'], 'fixed' => ['action' => 'urgent_sale']],
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
                'reject' => ['label' => 'رفض ريل', 'endpoint' => 'admin/reels', 'method' => 'POST', 'fields' => ['id' => 'معرّف الريل', 'reject_note' => 'سبب الرفض'], 'fixed' => ['action' => 'reject']],
                'delete' => ['label' => 'حذف ريل', 'endpoint' => 'admin/reels', 'method' => 'DELETE', 'fields' => ['id' => 'معرّف الريل']],
                'engagement' => ['label' => 'جدولة تفاعل', 'endpoint' => 'admin/engagement', 'method' => 'POST', 'permission' => 'engagement', 'fields' => ['target_kind' => 'reel', 'target_public_no' => 'رقم الريل', 'views_per_hour' => 'مشاهدات/ساعة', 'likes_per_hour' => 'لايكات/ساعة', 'hours' => 'المدة بالساعات']],
            ],
        ],
        'property_requests' => [
            'label' => 'طلبات العقار', 'icon' => 'RQ', 'group' => 'السوق', 'permission' => 'properties',
            'endpoint' => 'admin/property-requests', 'description' => 'فلاتر الطلبات وتغيير الحالة pending / in_progress / closed.',
            'tabs' => ['الطلبات', 'تغيير الحالة', 'اتصال/واتساب'],
            'operations' => [
                'status' => ['label' => 'تغيير حالة طلب', 'endpoint' => 'admin/property-requests', 'method' => 'POST', 'fields' => ['id' => 'معرّف الطلب', 'status' => 'pending/in_progress/closed']],
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
            'endpoint' => 'admin/user', 'description' => 'الشاشة الفرعية لعرض ملف مستخدم كما في تطبيق Admin.',
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
            'endpoint' => 'admin/reports', 'description' => 'تقارير الفترة وتصدير CSV كما في تطبيق Admin.',
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
            'endpoint' => 'health', 'description' => 'فحص API، broadcast، أقسام الرئيسية، وإجراءات المنطقة الخطرة.',
            'tabs' => ['Health', 'Broadcast', 'Home Sections', 'Danger Zone'],
            'operations' => [
                'broadcast' => ['label' => 'إرسال رسالة عامة', 'endpoint' => 'admin/broadcast', 'method' => 'POST', 'fields' => ['title' => 'العنوان', 'body' => 'المحتوى']],
                'home_section' => ['label' => 'تعديل أيقونة قسم رئيسية', 'endpoint' => 'admin/home-sections', 'method' => 'POST', 'fields' => ['section_key' => 'المفتاح', 'label' => 'التسمية', 'route_target' => 'المسار', 'icon_url' => 'رابط الأيقونة', 'sort_order' => 'الترتيب', 'is_active' => '1 أو 0']],
                'maintenance_on' => ['label' => 'تشغيل الصيانة', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'maintenance_on']],
                'maintenance_off' => ['label' => 'إيقاف الصيانة', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'maintenance_off']],
                'delete_all_properties' => ['label' => 'حذف كل المنشورات', 'endpoint' => 'admin/system', 'method' => 'POST', 'fields' => ['pin' => 'PIN'], 'fixed' => ['action' => 'delete_all_properties']],
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
    return array_filter(admin_sections(), static fn(array $section): bool => admin_can_access_section($section));
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
    $section = admin_section($sectionKey);
    if ($section === null || !admin_can_access_section($section)) {
        return ['ok' => false, 'error' => 'لا تملك صلاحية الوصول لهذا القسم'];
    }
    $baseQuery = is_array($section['query'] ?? null) ? $section['query'] : [];
    $allowedQuery = [];
    foreach (['q', 'status', 'scope', 'from', 'to', 'sort', 'governorate_id', 'id', 'thread_id'] as $key) {
        if (isset($query[$key]) && trim((string) $query[$key]) !== '') {
            $allowedQuery[$key] = trim((string) $query[$key]);
        }
    }
    return api_client()->get((string) $section['endpoint'], array_merge($baseQuery, $allowedQuery), auth_token());
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
    if (in_array($key, ['is_active', 'verified', 'resubmission_allowed', 'requires_review', 'is_unlimited', 'is_marketer'], true)) {
        return (int) $value;
    }
    if (in_array($key, ['sort_order', 'popup_duration_sec', 'days', 'views_per_hour', 'likes_per_hour', 'hours', 'amount', 'posting_listings_remaining', 'listings_limit'], true)) {
        return is_numeric($value) ? (int) $value : $value;
    }
    if ($key === 'permissions') {
        return array_values(array_filter(array_map('trim', explode(',', $value))));
    }
    return $value;
}

function run_admin_operation(string $sectionKey, string $operationKey, array $input): array
{
    $operation = admin_operation($sectionKey, $operationKey);
    if ($operation === null) {
        return ['ok' => false, 'error' => 'العملية غير متاحة أو لا تملك صلاحيتها'];
    }
    $payload = is_array($operation['fixed'] ?? null) ? $operation['fixed'] : [];
    $fields = is_array($operation['fields'] ?? null) ? $operation['fields'] : [];
    foreach (array_keys($fields) as $field) {
        if (array_key_exists($field, $input)) {
            $value = normalize_admin_value((string) $field, (string) $input[$field]);
            if ($value !== null) {
                $payload[$field] = $value;
            }
        }
    }
    $endpoint = (string) $operation['endpoint'];
    $method = strtoupper((string) ($operation['method'] ?? 'POST'));
    if ($method === 'UPLOAD') {
        $file = $_FILES['file'] ?? null;
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
    if ($method === 'DELETE') {
        return api_client()->delete($endpoint, $payload, auth_token());
    }
    return api_client()->post($endpoint, $payload, auth_token());
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
