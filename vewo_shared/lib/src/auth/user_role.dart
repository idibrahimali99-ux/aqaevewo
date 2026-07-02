enum UserRole { customer, office, admin }

extension UserRoleX on UserRole {
  String get labelAr => switch (this) {
        UserRole.customer => 'حساب شخصي',
        UserRole.office => 'مكتب عقاري',
        UserRole.admin => 'أدمن/موظف',
      };
}

