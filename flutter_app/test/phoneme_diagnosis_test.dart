import 'package:flutter_test/flutter_test.dart';
import 'package:korrect_app/utils/phoneme_diagnosis.dart';

void main() {
  group('diagnoseConfusion', () {
    test('정확히 인식되면 null (잘 발음함)', () {
      expect(diagnoseConfusion('구름', '구름'), isNull);
    });

    test('인식 실패(빈 문자열)면 null', () {
      expect(diagnoseConfusion('사과', ''), isNull);
    });

    test('된소리 ㄲ을 평음 ㄱ으로: 꿀 → 굴', () {
      final c = diagnoseConfusion('꿀', '굴');
      expect(c, isNotNull);
      expect(c!.phoneme, 'ㄲ');
      expect(c.tip, contains('힘')); // 된소리 팁
    });

    test('거센소리 ㅋ을 평음 ㄱ으로: 카드 → 가드', () {
      final c = diagnoseConfusion('카드', '가드');
      expect(c!.phoneme, 'ㅋ');
    });

    test('거센소리 ㅌ을 평음 ㄷ으로: 토끼 → 도끼', () {
      final c = diagnoseConfusion('토끼', '도끼');
      expect(c!.phoneme, 'ㅌ');
    });

    test('모음 ㅓ를 ㅗ로: 거리 → 고리', () {
      final c = diagnoseConfusion('거리', '고리');
      expect(c!.phoneme, 'ㅓ');
    });

    test('모음 ㅡ를 ㅜ로: 그림 → 구림', () {
      final c = diagnoseConfusion('그림', '구림');
      expect(c!.phoneme, 'ㅡ');
    });

    test('계열 밖/길이 다름이면 일반 안내 (phoneme=null, 결과는 있음)', () {
      final c = diagnoseConfusion('안녕하세요', '안녕');
      expect(c, isNotNull);
      expect(c!.phoneme, isNull);
    });

    test('자음 계열이 아예 다르면(ㄱ vs ㅁ) 일반 안내', () {
      final c = diagnoseConfusion('감', '맘');
      expect(c, isNotNull);
      expect(c!.phoneme, isNull);
    });
  });

  group('recognitionScore', () {
    test('목표와 정확히 일치하면 100', () {
      expect(recognitionScore('배고파요', '배고파요'), 100);
    });

    test('완전히 다른 단어면 낮음', () {
      expect(recognitionScore('배고파요', '나인지 모르겠다') < 50, isTrue);
    });

    test('한 음소만 다르면 높음 (꿀 vs 굴)', () {
      final s = recognitionScore('꿀', '굴'); // ㄲㅜㄹ vs ㄱㅜㄹ → 1/3 차이
      expect(s > 60 && s < 100, isTrue);
    });

    test('인식 실패(빈값)면 0', () {
      expect(recognitionScore('배고파요', ''), 0);
    });

    test('잘함>엉터리 순서가 잡힌다', () {
      final good = recognitionScore('배고파요', '배고파요');
      final bad = recognitionScore('배고파요', '비구파유오');
      expect(good > bad, isTrue);
    });
  });
}
