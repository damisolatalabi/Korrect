import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionRecord {
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
  final int turnCount;
  final DateTime date;

  SessionRecord({
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
    required this.turnCount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
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
        'turnCount': turnCount,
        'date': date.toIso8601String(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
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
        turnCount: json['turnCount'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

class ProgressService {
  static const _key = 'korrect_session_history';

  static Future<void> saveSession(SessionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.add(record);
    final encoded = history.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  static Future<List<SessionRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => SessionRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
