import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/sleep_scoring.dart';
import 'package:hlth_app/features/blood_pressure/bp_controller.dart';

void main() {
  group('BpController.ageFromDob', () {
    test('null DOB falls back to 30 (band default)', () {
      expect(BpController.ageFromDob(null), 30);
    });

    test('birthday not yet reached this year subtracts one', () {
      final now = DateTime.now();
      // A DOB 30 years ago, one day in the future → age 29.
      final dob = DateTime(now.year - 30, now.month, now.day)
          .add(const Duration(days: 1));
      expect(BpController.ageFromDob(dob), 29);
    });

    test('clamps to the band-accepted 13–100 range', () {
      final now = DateTime.now();
      expect(BpController.ageFromDob(DateTime(now.year - 5)), 13);
      expect(BpController.ageFromDob(DateTime(now.year - 130)), 100);
    });
  });

  group('BpController.maxHrForAge', () {
    test('classic 220 − age', () {
      expect(BpController.maxHrForAge(30), 190);
    });

    test('clamps to the band warn-threshold range 120–200', () {
      expect(BpController.maxHrForAge(13), 200);
      expect(BpController.maxHrForAge(100), 120);
    });
  });

  group('deepContinuityScore', () {
    test('reference point: 110 min deep ≈ 91', () {
      expect(deepContinuityScore(110), 92); // (110/120*100).round()
    });

    test('caps at 100 and floors at 0', () {
      expect(deepContinuityScore(180), 100);
      expect(deepContinuityScore(0), 0);
    });
  });
}
