import '../services/progress_service.dart';

class PronunciationTip {
  final String title;
  final String guide;

  const PronunciationTip({
    required this.title,
    required this.guide,
  });
}

class WordPracticeGuide {
  final String word;
  final double? score;
  final double? vowelScore;
  final double? formantF1;
  final double? formantF2;
  final List<PronunciationTip> tips;

  const WordPracticeGuide({
    required this.word,
    required this.score,
    this.vowelScore,
    this.formantF1,
    this.formantF2,
    required this.tips,
  });
}

const _hangulBase = 0xAC00;
const _hangulEnd = 0xD7A3;
const _jungCount = 21;
const _jongCount = 28;

const _jungseong = [
  'ㅏ',
  'ㅐ',
  'ㅑ',
  'ㅒ',
  'ㅓ',
  'ㅔ',
  'ㅕ',
  'ㅖ',
  'ㅗ',
  'ㅘ',
  'ㅙ',
  'ㅚ',
  'ㅛ',
  'ㅜ',
  'ㅝ',
  'ㅞ',
  'ㅟ',
  'ㅠ',
  'ㅡ',
  'ㅢ',
  'ㅣ',
];

Set<String> _vowelsOf(String word) {
  final result = <String>{};
  for (final rune in word.runes) {
    if (rune < _hangulBase || rune > _hangulEnd) continue;
    final offset = rune - _hangulBase;
    final jung = (offset % (_jungCount * _jongCount)) ~/ _jongCount;
    result.add(_jungseong[jung]);
  }
  return result;
}

// 발화 전체 평균 포먼트만으로는 '어느 모음이 어느 방향으로 틀렸는지' 단정할 수 없어
// (모음별 원어민 기준값이 없음) 방향 진단 대신 단어 안의 모음별 연습 포인트만 제공한다.
List<PronunciationTip> tipsForWord(String word) {
  final vowels = _vowelsOf(word);
  final tips = <PronunciationTip>[];
  final targetVowels = vowels.intersection({'ㅓ', 'ㅗ', 'ㅡ', 'ㅜ'});

  if (targetVowels.contains('ㅓ') || targetVowels.contains('ㅗ')) {
    tips.add(const PronunciationTip(
      title: 'ㅓ/ㅗ 연습 포인트',
      guide: 'ㅓ는 입을 자연스럽게 벌리고, ㅗ는 입술을 둥글게 모아 소리내요.',
    ));
  }
  if (targetVowels.contains('ㅡ') || targetVowels.contains('ㅜ')) {
    tips.add(const PronunciationTip(
      title: 'ㅡ/ㅜ 연습 포인트',
      guide: 'ㅡ는 입술을 평평하게, ㅜ는 입술을 앞으로 둥글게 내밀어 발음해요.',
    ));
  }

  if (tips.isEmpty) {
    tips.add(const PronunciationTip(
      title: '모음 연습 포인트',
      guide: '단어 안의 모음을 길게 한 번, 짧게 한 번 말해보며 입모양을 크게 확인해보세요.',
    ));
  }

  return tips.take(2).toList();
}

List<WordPracticeGuide> buildPracticeGuides(
  List<WordRecord> words, {
  double threshold = 75,
  int limit = 3,
}) {
  final targets = words
      .where((word) => word.word.trim().isNotEmpty)
      .where((word) => word.score == null || word.score! < threshold)
      .toList()
    ..sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));

  return targets
      .take(limit)
      .map((word) => WordPracticeGuide(
            word: word.word,
            score: word.score,
            vowelScore: word.vowelScore,
            formantF1: word.formantF1,
            formantF2: word.formantF2,
            tips: tipsForWord(word.word),
          ))
      .toList();
}
