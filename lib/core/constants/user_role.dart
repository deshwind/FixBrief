enum UserRole {
  customer,
  repairer;

  static UserRole fromDatabase(String value) {
    return switch (value) {
      'customer' => UserRole.customer,
      'repairer' => UserRole.repairer,
      _ => throw ArgumentError.value(value, 'value', 'Unknown user role'),
    };
  }

  String get databaseValue => name;
}
