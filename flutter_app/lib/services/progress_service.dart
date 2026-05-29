import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WordRecord {
  final String word;
  final double? score;
  final double? vowelScore;
  final double? formantF1;
  final double? formantF2;

  const WordRecord({
    required this.word,
    this.score,
    this.vowelScore,
    this.formantF1,
    this.formantF2,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'score': score,
        'vowelScore': vowelScore,
        'formantF1': formantF1,
        'formantF2': formantF2,
      };

  factory WordRecord.fromJson(Map<String, dynamic> json) => WordRecord(
        word: json['word'] as String,
        score: json['score'] != null ? (json['score'] as num).toDouble() : null,
        vowelScore: json['vowelScore'] != null
            ? (json['vowelScore'] as num).toDouble()
            : null,
        formantF1: json['formantF1'] != null
            ? (json['formantF1'] as num).toDouble()
            : null,
        formantF2: json['formantF2'] != null
            ? (json['formantF2'] as num).toDouble()
            : null,
      );
}

class TurnRecord {
  final int turnNumber;
  final String text;
  final double? totalScore;
  final double? profileScore;
  final double? intonationScore;
  final double? rhythmScore;
  final double? mfccScore;
  final double? voiceScore;
  final double? vowelScore;
  final List<WordRecord> wordRecords;
  final DateTime date;

  const TurnRecord({
    required this.turnNumber,
    required this.text,
    this.totalScore,
    this.profileScore,
    this.intonationScore,
    this.rhythmScore,
    this.mfccScore,
    this.voiceScore,
    this.vowelScore,
    this.wordRecords = const [],
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'turnNumber': turnNumber,
        'text': text,
        'totalScore': totalScore,
        'profileScore': profileScore,
        'intonationScore': intonationScore,
        'rhythmScore': rhythmScore,
        'mfccScore': mfccScore,
        'voiceScore': voiceScore,
        'vowelScore': vowelScore,
        'wordRecords': wordRecords.map((w) => w.toJson()).toList(),
        'date': date.toIso8601String(),
      };

  factory TurnRecord.fromJson(Map<String, dynamic> json) {
    final wordsRaw = json['wordRecords'] as List?;
    return TurnRecord(
      turnNumber: json['turnNumber'] as int,
      text: json['text'] as String? ?? '',
      totalScore: json['totalScore'] != null
          ? (json['totalScore'] as num).toDouble()
          : null,
      profileScore: json['profileScore'] != null
          ? (json['profileScore'] as num).toDouble()
          : null,
      intonationScore: json['intonationScore'] != null
          ? (json['intonationScore'] as num).toDouble()
          : null,
      rhythmScore: json['rhythmScore'] != null
          ? (json['rhythmScore'] as num).toDouble()
          : null,
      mfccScore: json['mfccScore'] != null
          ? (json['mfccScore'] as num).toDouble()
          : null,
      voiceScore: json['voiceScore'] != null
          ? (json['voiceScore'] as num).toDouble()
          : null,
      vowelScore: json['vowelScore'] != null
          ? (json['vowelScore'] as num).toDouble()
          : null,
      wordRecords: wordsRaw == null
          ? const []
          : wordsRaw
              .map((e) => WordRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class SessionRecord {
  final String? sessionId;
  final String scenarioId;
  final String scenarioTitle;
  final double? totalScore;
  final double? rhythmScore;
  final double? stressScore;
  final double? mfccScore;
  final double? profileScore;
  final double? intonationScore;
  final double? voiceScore;
  final double? vowelScore;
  final double? syllableScore;
  final double? slopeScore;
  final List<WordRecord> wordRecords;
  final List<TurnRecord> turnRecords;
  final int turnCount;
  final DateTime date;

  SessionRecord({
    this.sessionId,
    required this.scenarioId,
    required this.scenarioTitle,
    this.totalScore,
    this.rhythmScore,
    this.stressScore,
    this.mfccScore,
    this.profileScore,
    this.intonationScore,
    this.voiceScore,
    this.vowelScore,
    this.syllableScore,
    this.slopeScore,
    this.wordRecords = const [],
    this.turnRecords = const [],
    required this.turnCount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'scenarioId': scenarioId,
        'scenarioTitle': scenarioTitle,
        'totalScore': totalScore,
        'rhythmScore': rhythmScore,
        'stressScore': stressScore,
        'mfccScore': mfccScore,
        'profileScore': profileScore,
        'intonationScore': intonationScore,
        'voiceScore': voiceScore,
        'vowelScore': vowelScore,
        'syllableScore': syllableScore,
        'slopeScore': slopeScore,
        'wordRecords': wordRecords.map((w) => w.toJson()).toList(),
        'turnRecords': turnRecords.map((t) => t.toJson()).toList(),
        'turnCount': turnCount,
        'date': date.toIso8601String(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final wordsRaw = json['wordRecords'] as List?;
    final turnsRaw = json['turnRecords'] as List?;
    return SessionRecord(
      sessionId: json['sessionId'] as String?,
      scenarioId: json['scenarioId'] as String,
      scenarioTitle: json['scenarioTitle'] as String,
      totalScore: json['totalScore'] != null
          ? (json['totalScore'] as num).toDouble()
          : null,
      rhythmScore: json['rhythmScore'] != null
          ? (json['rhythmScore'] as num).toDouble()
          : null,
      stressScore: json['stressScore'] != null
          ? (json['stressScore'] as num).toDouble()
          : null,
      mfccScore: json['mfccScore'] != null
          ? (json['mfccScore'] as num).toDouble()
          : null,
      profileScore: json['profileScore'] != null
          ? (json['profileScore'] as num).toDouble()
          : null,
      intonationScore: json['intonationScore'] != null
          ? (json['intonationScore'] as num).toDouble()
          : null,
      voiceScore: json['voiceScore'] != null
          ? (json['voiceScore'] as num).toDouble()
          : null,
      vowelScore: json['vowelScore'] != null
          ? (json['vowelScore'] as num).toDouble()
          : null,
      syllableScore: json['syllableScore'] != null
          ? (json['syllableScore'] as num).toDouble()
          : null,
      slopeScore: json['slopeScore'] != null
          ? (json['slopeScore'] as num).toDouble()
          : null,
      wordRecords: wordsRaw == null
          ? const []
          : wordsRaw
              .map((e) => WordRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
      turnRecords: turnsRaw == null
          ? const []
          : turnsRaw
              .map((e) => TurnRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
      turnCount: json['turnCount'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class ProgressService {
  static const _key = 'korrect_session_history';

  static List<SessionRecord> _demoHistory() {
    final now = DateTime.now();
    return [
      SessionRecord(
        scenarioId: 'hospital',
        scenarioTitle: '병원',
        totalScore: 84,
        profileScore: 86,
        intonationScore: 88,
        rhythmScore: 79,
        mfccScore: 82,
        voiceScore: 91,
        stressScore: 76,
        vowelScore: 89,
        syllableScore: 85,
        slopeScore: 80,
        wordRecords: const [
          WordRecord(word: '안녕하세요', score: 88),
          WordRecord(word: '어디가', score: 74),
          WordRecord(word: '아파요', score: 83),
          WordRecord(word: '병원', score: 91),
        ],
        turnRecords: [
          TurnRecord(
            turnNumber: 1,
            text: '안녕하세요',
            totalScore: 88,
            profileScore: 88,
            intonationScore: 90,
            rhythmScore: 82,
            voiceScore: 92,
            vowelScore: 89,
            wordRecords: const [
              WordRecord(word: '안녕하세요', score: 88, vowelScore: 90),
            ],
            date: now.subtract(const Duration(hours: 2, minutes: 15)),
          ),
          TurnRecord(
            turnNumber: 2,
            text: '머리가 아파요',
            totalScore: 79,
            profileScore: 79,
            intonationScore: 84,
            rhythmScore: 75,
            voiceScore: 88,
            vowelScore: 82,
            wordRecords: const [
              WordRecord(word: '머리가', score: 76, vowelScore: 80),
              WordRecord(word: '아파요', score: 83, vowelScore: 84),
            ],
            date: now.subtract(const Duration(hours: 2, minutes: 10)),
          ),
          TurnRecord(
            turnNumber: 3,
            text: '어제부터 아팠어요',
            totalScore: 83,
            profileScore: 83,
            intonationScore: 86,
            rhythmScore: 78,
            voiceScore: 91,
            vowelScore: 87,
            wordRecords: const [
              WordRecord(word: '어제부터', score: 81, vowelScore: 86),
              WordRecord(word: '아팠어요', score: 85, vowelScore: 88),
            ],
            date: now.subtract(const Duration(hours: 2, minutes: 5)),
          ),
          TurnRecord(
            turnNumber: 4,
            text: '감사합니다',
            totalScore: 91,
            profileScore: 91,
            intonationScore: 92,
            rhythmScore: 88,
            voiceScore: 95,
            vowelScore: 93,
            wordRecords: const [
              WordRecord(word: '감사합니다', score: 91, vowelScore: 93),
            ],
            date: now.subtract(const Duration(hours: 2)),
          ),
        ],
        turnCount: 4,
        date: now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
      SessionRecord(
        scenarioId: 'bank',
        scenarioTitle: '은행',
        totalScore: 72,
        profileScore: 70,
        intonationScore: 68,
        rhythmScore: 75,
        mfccScore: 73,
        voiceScore: 81,
        stressScore: 66,
        vowelScore: 78,
        syllableScore: 74,
        slopeScore: 69,
        wordRecords: const [
          WordRecord(word: '계좌', score: 62),
          WordRecord(word: '만들고', score: 77),
          WordRecord(word: '싶어요', score: 82),
          WordRecord(word: '신분증', score: 68),
        ],
        turnRecords: [
          TurnRecord(
            turnNumber: 1,
            text: '돈을 바꾸고 싶어요',
            totalScore: 68,
            profileScore: 68,
            intonationScore: 64,
            rhythmScore: 72,
            voiceScore: 79,
            vowelScore: 74,
            wordRecords: const [
              WordRecord(word: '돈을', score: 61, vowelScore: 72),
              WordRecord(word: '바꾸고', score: 70, vowelScore: 76),
              WordRecord(word: '싶어요', score: 73, vowelScore: 75),
            ],
            date: now.subtract(const Duration(days: 1, hours: 4)),
          ),
          TurnRecord(
            turnNumber: 2,
            text: '계좌를 만들고 싶어요',
            totalScore: 74,
            profileScore: 74,
            intonationScore: 69,
            rhythmScore: 78,
            voiceScore: 82,
            vowelScore: 80,
            wordRecords: const [
              WordRecord(word: '계좌를', score: 66, vowelScore: 78),
              WordRecord(word: '만들고', score: 77, vowelScore: 80),
              WordRecord(word: '싶어요', score: 82, vowelScore: 82),
            ],
            date: now.subtract(const Duration(days: 1, hours: 3, minutes: 55)),
          ),
          TurnRecord(
            turnNumber: 3,
            text: '신분증 있어요',
            totalScore: 75,
            profileScore: 75,
            intonationScore: 71,
            rhythmScore: 76,
            voiceScore: 82,
            vowelScore: 79,
            wordRecords: const [
              WordRecord(word: '신분증', score: 68, vowelScore: 77),
              WordRecord(word: '있어요', score: 82, vowelScore: 81),
            ],
            date: now.subtract(const Duration(days: 1, hours: 3, minutes: 50)),
          ),
        ],
        turnCount: 3,
        date: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      SessionRecord(
        scenarioId: 'immigration',
        scenarioTitle: '출입국',
        totalScore: 63,
        profileScore: 61,
        intonationScore: 58,
        rhythmScore: 65,
        mfccScore: 67,
        voiceScore: 76,
        stressScore: 55,
        vowelScore: 70,
        syllableScore: 64,
        slopeScore: 59,
        wordRecords: const [
          WordRecord(word: '비자', score: 71),
          WordRecord(word: '연장', score: 57),
          WordRecord(word: '예약', score: 66),
          WordRecord(word: '서류', score: 60),
        ],
        turnRecords: [
          TurnRecord(
            turnNumber: 1,
            text: '비자를 연장하고 싶어요',
            totalScore: 60,
            profileScore: 60,
            intonationScore: 55,
            rhythmScore: 63,
            voiceScore: 74,
            vowelScore: 68,
            wordRecords: const [
              WordRecord(word: '비자를', score: 71, vowelScore: 70),
              WordRecord(word: '연장하고', score: 57, vowelScore: 66),
              WordRecord(word: '싶어요', score: 64, vowelScore: 69),
            ],
            date: now.subtract(const Duration(days: 3, hours: 1)),
          ),
          TurnRecord(
            turnNumber: 2,
            text: '어떤 서류가 필요해요',
            totalScore: 66,
            profileScore: 66,
            intonationScore: 61,
            rhythmScore: 67,
            voiceScore: 78,
            vowelScore: 72,
            wordRecords: const [
              WordRecord(word: '어떤', score: 62, vowelScore: 70),
              WordRecord(word: '서류가', score: 60, vowelScore: 71),
              WordRecord(word: '필요해요', score: 76, vowelScore: 75),
            ],
            date: now.subtract(const Duration(days: 3, minutes: 55)),
          ),
        ],
        turnCount: 2,
        date: now.subtract(const Duration(days: 3, hours: 1)),
      ),
      SessionRecord(
        scenarioId: 'hospital',
        scenarioTitle: '병원',
        totalScore: 91,
        profileScore: 92,
        intonationScore: 90,
        rhythmScore: 87,
        mfccScore: 89,
        voiceScore: 96,
        stressScore: 84,
        vowelScore: 94,
        syllableScore: 90,
        slopeScore: 88,
        wordRecords: const [
          WordRecord(word: '진료', score: 93),
          WordRecord(word: '예약했어요', score: 89),
          WordRecord(word: '감사합니다', score: 96),
        ],
        turnRecords: [
          TurnRecord(
            turnNumber: 1,
            text: '진료 예약했어요',
            totalScore: 90,
            profileScore: 90,
            intonationScore: 89,
            rhythmScore: 86,
            voiceScore: 95,
            vowelScore: 92,
            wordRecords: const [
              WordRecord(word: '진료', score: 93, vowelScore: 94),
              WordRecord(word: '예약했어요', score: 89, vowelScore: 90),
            ],
            date: now.subtract(const Duration(days: 5, hours: 6)),
          ),
          TurnRecord(
            turnNumber: 2,
            text: '목이 아파요',
            totalScore: 88,
            profileScore: 88,
            intonationScore: 86,
            rhythmScore: 85,
            voiceScore: 94,
            vowelScore: 91,
            wordRecords: const [
              WordRecord(word: '목이', score: 86, vowelScore: 89),
              WordRecord(word: '아파요', score: 90, vowelScore: 92),
            ],
            date: now.subtract(const Duration(days: 5, hours: 5, minutes: 55)),
          ),
          TurnRecord(
            turnNumber: 3,
            text: '약은 어디에서 받아요',
            totalScore: 92,
            profileScore: 92,
            intonationScore: 91,
            rhythmScore: 88,
            voiceScore: 96,
            vowelScore: 94,
            wordRecords: const [
              WordRecord(word: '약은', score: 91, vowelScore: 94),
              WordRecord(word: '어디에서', score: 93, vowelScore: 95),
              WordRecord(word: '받아요', score: 92, vowelScore: 93),
            ],
            date: now.subtract(const Duration(days: 5, hours: 5, minutes: 50)),
          ),
          TurnRecord(
            turnNumber: 4,
            text: '감사합니다',
            totalScore: 96,
            profileScore: 96,
            intonationScore: 94,
            rhythmScore: 92,
            voiceScore: 98,
            vowelScore: 96,
            wordRecords: const [
              WordRecord(word: '감사합니다', score: 96, vowelScore: 96),
            ],
            date: now.subtract(const Duration(days: 5, hours: 5, minutes: 45)),
          ),
        ],
        turnCount: 4,
        date: now.subtract(const Duration(days: 5, hours: 6)),
      ),
    ];
  }

  // 실제 저장소에 들어있는 기록만 읽는다 (데모는 섞지 않음).
  static Future<List<SessionRecord>> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => SessionRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _persist(List<SessionRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = history.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// 같은 sessionId가 있으면 갱신, 없으면 새로 추가한다.
  /// 매 턴마다 호출해도 한 세션은 한 기록으로 유지된다.
  static Future<void> saveOrUpdateSession(SessionRecord record) async {
    final history = await _loadStored();
    final id = record.sessionId;
    final idx = id == null ? -1 : history.indexWhere((r) => r.sessionId == id);
    if (idx >= 0) {
      history[idx] = record;
    } else {
      history.add(record);
    }
    await _persist(history);
  }

  static Future<void> saveSession(SessionRecord record) =>
      saveOrUpdateSession(record);

  static Future<List<SessionRecord>> loadHistory() async {
    final stored = await _loadStored();
    if (stored.isEmpty) {
      return _demoHistory();
    }
    return stored;
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── 약한 음소 누적 (드릴에서 STT가 잡아낸 음소 혼동을 세션 넘어 모음) ──
  static const _weakPhonemeKey = 'korrect_weak_phonemes';

  /// 드릴에서 음소 혼동이 잡힐 때마다 해당 음소의 횟수를 1 올린다.
  static Future<void> recordWeakPhoneme(String phoneme) async {
    if (phoneme.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeCounts(prefs.getString(_weakPhonemeKey));
    counts[phoneme] = (counts[phoneme] ?? 0) + 1;
    await prefs.setString(_weakPhonemeKey, jsonEncode(counts));
  }

  /// 약한 음소를 횟수 많은 순으로 반환.
  static Future<List<MapEntry<String, int>>> loadWeakPhonemes() async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeCounts(prefs.getString(_weakPhonemeKey));
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  static Future<void> clearWeakPhonemes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weakPhonemeKey);
  }

  static Map<String, int> _decodeCounts(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}
