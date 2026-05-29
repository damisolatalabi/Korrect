/// STT를 '심판'으로 쓰는 음소 진단.
///
/// 음향적으로 "ㄱ을 ㅋ처럼 냈다"를 확정하는 건 (forced alignment + 음소 음향모델이
/// 필요해) 현재 구조로 불가능하다. 대신 목표 단어와 Whisper가 인식한 단어를 자모로
/// 비교한다. 목표가 '꿀'인데 '굴'로 인식됐다면, 그게 ㄲ→ㄱ 혼동의 정직한 증거다.
/// (확정이 아니라 "그렇게 들렸다"는 신호이므로 피드백 문구도 단정하지 않는다.)

class PhonemeConfusion {
  final String description; // 예: "'꿀'을 '굴'처럼 발음한 것 같아요"
  final String tip; //         예: "ㄲ은 목에 힘을 주고 짧고 단단하게 소리내요."
  final String? phoneme; //    혼동된 '목표' 음소 (예: 'ㄲ', 'ㅓ'). 누적 통계용. 일반 피드백이면 null.

  const PhonemeConfusion({
    required this.description,
    required this.tip,
    this.phoneme,
  });
}

const _hangulBase = 0xAC00;
const _hangulEnd = 0xD7A3;

const _cho = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
];
const _jung = [
  'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ',
  'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'
];
const _jong = [
  '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ',
  'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
];

class _Syllable {
  final String cho;
  final String jung;
  final String jong;
  const _Syllable(this.cho, this.jung, this.jong);
}

String _normalize(String s) =>
    s.replaceAll(RegExp(r'[^가-힣]'), '');

List<_Syllable> _decompose(String word) {
  final result = <_Syllable>[];
  for (final rune in word.runes) {
    if (rune < _hangulBase || rune > _hangulEnd) continue;
    final offset = rune - _hangulBase;
    final cho = offset ~/ (21 * 28);
    final jung = (offset % (21 * 28)) ~/ 28;
    final jong = offset % 28;
    result.add(_Syllable(_cho[cho], _jung[jung], _jong[jong]));
  }
  return result;
}

/// 한 단어를 자모(초성·중성·종성) 평면 시퀀스로 분해.
List<String> _jamoSeq(String word) {
  final out = <String>[];
  for (final s in _decompose(_normalize(word))) {
    out.add(s.cho);
    out.add(s.jung);
    if (s.jong.isNotEmpty) out.add(s.jong);
  }
  return out;
}

int _levenshtein(List<String> a, List<String> b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// STT가 목표 단어를 얼마나 정확히 받아썼는지 0~100 (자모 유사도).
/// 발음 정확도/명료도의 정직한 대용 신호 — profile_score보다 발음 품질에 가깝다.
/// 목표나 인식이 비면 0.
double recognitionScore(String target, String recognized) {
  final t = _jamoSeq(target);
  final r = _jamoSeq(recognized);
  if (t.isEmpty || r.isEmpty) return 0;
  final dist = _levenshtein(t, r);
  final maxLen = t.length > r.length ? t.length : r.length;
  final sim = 1 - dist / maxLen;
  return (sim < 0 ? 0.0 : sim) * 100;
}

// 자음 조음 계열: 같은 계열 안에서 평음↔거센소리↔된소리 혼동을 잡는다.
const _consonantFamily = {
  'ㄱ': 'g', 'ㅋ': 'g', 'ㄲ': 'g',
  'ㄷ': 'd', 'ㅌ': 'd', 'ㄸ': 'd',
  'ㅂ': 'b', 'ㅍ': 'b', 'ㅃ': 'b',
  'ㅈ': 'j', 'ㅊ': 'j', 'ㅉ': 'j',
  'ㅅ': 's', 'ㅆ': 's',
};
const _consonantType = {
  'ㄱ': '평음', 'ㄷ': '평음', 'ㅂ': '평음', 'ㅈ': '평음', 'ㅅ': '평음',
  'ㅋ': '거센소리', 'ㅌ': '거센소리', 'ㅍ': '거센소리', 'ㅊ': '거센소리',
  'ㄲ': '된소리', 'ㄸ': '된소리', 'ㅃ': '된소리', 'ㅉ': '된소리', 'ㅆ': '된소리',
};

String? _consonantTip(String target) {
  switch (_consonantType[target]) {
    case '평음':
      return '$target은 숨과 힘을 빼고 부드럽게 소리내요.';
    case '거센소리':
      return '$target은 숨을 강하게 "확" 터뜨리며 소리내요.';
    case '된소리':
      return '$target은 목에 힘을 주고 짧고 단단하게 소리내요.';
  }
  return null;
}

// 고려인 학습자가 자주 헷갈리는 모음쌍.
const _vowelTip = {
  'ㅓ': 'ㅓ는 입술을 둥글게 모으지 말고 턱을 자연스럽게 내려 소리내요.',
  'ㅗ': 'ㅗ는 입술을 동그랗게 모아 앞으로 내밀어 소리내요.',
  'ㅡ': 'ㅡ는 입술을 옆으로 평평하게 당겨 소리내요.',
  'ㅜ': 'ㅜ는 입술을 앞으로 쭉 내밀어 동그랗게 소리내요.',
};
const _vowelPair = {'ㅓ': 'ㅗ', 'ㅗ': 'ㅓ', 'ㅡ': 'ㅜ', 'ㅜ': 'ㅡ'};

/// 목표 단어와 인식된 단어를 비교해 음소 혼동을 진단한다.
/// 같으면(정확히 인식) null, 인식 실패/빈값이면 null(신호 부족).
PhonemeConfusion? diagnoseConfusion(String target, String recognized) {
  final t = _normalize(target);
  final r = _normalize(recognized);
  if (t.isEmpty || r.isEmpty) return null;
  if (t == r) return null; // 목표대로 인식됨 = 잘 발음함

  final ts = _decompose(t);
  final rs = _decompose(r);

  if (ts.length == rs.length) {
    for (var i = 0; i < ts.length; i++) {
      // 1) 자음(초성) 계열 혼동 우선
      final tc = ts[i].cho, rc = rs[i].cho;
      if (tc != rc &&
          _consonantFamily[tc] != null &&
          _consonantFamily[tc] == _consonantFamily[rc]) {
        return PhonemeConfusion(
          description:
              '"$target"을(를) "$recognized"처럼 발음한 것 같아요 ($tc → $rc).',
          tip: _consonantTip(tc) ?? 'ㄱ/ㅋ/ㄲ처럼 소리의 세기를 구분해보세요.',
          phoneme: tc,
        );
      }
      // 2) 모음(중성) 혼동
      final tj = ts[i].jung, rj = rs[i].jung;
      if (tj != rj && _vowelPair[tj] == rj) {
        return PhonemeConfusion(
          description:
              '"$target"의 "$tj"가 "$rj"처럼 들렸어요.',
          tip: _vowelTip[tj] ?? 'ㅓ/ㅗ, ㅡ/ㅜ는 입술 모양으로 구분해요.',
          phoneme: tj,
        );
      }
    }
  }

  // 알려진 음소쌍은 아니지만 다른 단어로 들린 경우 — 단정하지 않는다.
  return PhonemeConfusion(
    description: '"$target" 대신 "$recognized"로 들렸어요.',
    tip: '한 음절씩 천천히, 또박또박 다시 말해볼까요?',
  );
}
