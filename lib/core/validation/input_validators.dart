abstract final class InputValidators {
  static final _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  static String? requiredText(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredText(value, label: 'Email');
    if (requiredError != null) {
      return requiredError;
    }
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredText(value, label: 'Password');
    if (requiredError != null) {
      return requiredError;
    }
    final password = value!;
    if (password.length < 12) {
      return 'Use at least 12 characters.';
    }
    if (!RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      return 'Include uppercase, lowercase, and a number.';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredError = requiredText(value, label: 'Phone number');
    if (requiredError != null) {
      return requiredError;
    }
    final digits = value!.replaceAll(RegExp('[^0-9+]'), '');
    if (digits.length < 8 || digits.length > 16) {
      return 'Enter a valid phone number with country code.';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, {required String label}) {
    final requiredError = requiredText(value, label: label);
    if (requiredError != null) {
      return requiredError;
    }
    final parsed = num.tryParse(value!.trim());
    if (parsed == null || parsed < 0) {
      return 'Enter a valid $label.';
    }
    return null;
  }
}
