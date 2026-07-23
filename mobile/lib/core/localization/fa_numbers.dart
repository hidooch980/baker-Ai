/// تبدیل ارقام انگلیسی/لاتین به فارسی برای نمایش در UI.
/// ورودی کاربر همواره به ارقام انگلیسی قابل قبول است (بدون تبدیل).
class FaNumbers {
  FaNumbers._();

  static const Map<String, String> _enToFa = {
    '0': '۰',
    '1': '۱',
    '2': '۲',
    '3': '۳',
    '4': '۴',
    '5': '۵',
    '6': '۶',
    '7': '۷',
    '8': '۸',
    '9': '۹',
  };

  static String toFarsi(Object value) {
    final input = value.toString();
    final buffer = StringBuffer();
    for (final char in input.split('')) {
      buffer.write(_enToFa[char] ?? char);
    }
    return buffer.toString();
  }

  static String formatCurrency(num amount, {String unit = 'تومان'}) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    return '${toFarsi(formatted)} $unit';
  }
}
