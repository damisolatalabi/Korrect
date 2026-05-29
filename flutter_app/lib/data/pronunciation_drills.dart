/// 고려인 학습자가 자주 어려워하는 발음을 중심으로 한 드릴 세트.
/// (러시아어에 없는 대립: 평음/거센소리/된소리, ㅓ/ㅗ, ㅡ/ㅜ, 그리고 러시아어식 강세)
/// 알고리즘이 아니라 '콘텐츠'이므로 단어는 자유롭게 추가/교체 가능.

class DrillSet {
  final String id;
  final String title; // "ㄱ · ㅋ · ㄲ"
  final String subtitle; // 짧은 설명
  final String emoji;
  final List<String> words; // 반복 연습할 목표 단어

  const DrillSet({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.words,
  });
}

/// 약한 음소를 해당 드릴 세트로 연결한다 (누적된 약점 → 맞춤 연습).
DrillSet? drillSetForPhoneme(String phoneme) {
  const toSetId = {
    'ㄱ': 'consonant_g', 'ㅋ': 'consonant_g', 'ㄲ': 'consonant_g',
    'ㄷ': 'consonant_d_b', 'ㅌ': 'consonant_d_b', 'ㄸ': 'consonant_d_b',
    'ㅂ': 'consonant_d_b', 'ㅍ': 'consonant_d_b', 'ㅃ': 'consonant_d_b',
    'ㅓ': 'vowel_eo_o', 'ㅗ': 'vowel_eo_o',
    'ㅡ': 'vowel_eu_u', 'ㅜ': 'vowel_eu_u',
  };
  final id = toSetId[phoneme];
  if (id == null) return null;
  for (final set in koryoSaramDrills) {
    if (set.id == id) return set;
  }
  return null;
}

const koryoSaramDrills = <DrillSet>[
  DrillSet(
    id: 'consonant_g',
    title: 'ㄱ · ㅋ · ㄲ',
    subtitle: '평음 · 거센소리 · 된소리',
    emoji: '💨',
    words: ['가방', '카드', '까치', '코끼리', '꿀', '토끼'],
  ),
  DrillSet(
    id: 'consonant_d_b',
    title: 'ㄷ·ㅌ·ㄸ / ㅂ·ㅍ·ㅃ',
    subtitle: '평음 · 거센소리 · 된소리',
    emoji: '🌬️',
    words: ['다리', '타조', '딸기', '바지', '포도', '빵'],
  ),
  DrillSet(
    id: 'vowel_eo_o',
    title: 'ㅓ · ㅗ',
    subtitle: '입술 모양으로 구분',
    emoji: '👄',
    words: ['거리', '고리', '너구리', '도토리', '어머니', '오리'],
  ),
  DrillSet(
    id: 'vowel_eu_u',
    title: 'ㅡ · ㅜ',
    subtitle: '입술 모양으로 구분',
    emoji: '👅',
    words: ['그림', '구름', '드라마', '두부', '느낌', '누나'],
  ),
  DrillSet(
    id: 'stress',
    title: '또박또박 강세',
    subtitle: '러시아어식 강세 줄이기',
    emoji: '🎵',
    words: ['사과', '바나나', '도서관', '선생님', '안녕하세요'],
  ),
];
