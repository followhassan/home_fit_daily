import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/constants/app_colors.dart';

void main() {
  test('App colors are defined correctly', () {
    expect(AppColors.deepBlack.toARGB32(), 0xFF0D0D0D);
    expect(AppColors.premiumPink.toARGB32(), 0xFFFF4FA3);
  });
}
