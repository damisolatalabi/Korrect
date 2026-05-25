class WordScore {
  final String word;
  final double start;
  final double end;
  final double? score;

  WordScore({required this.word, required this.start, required this.end, this.score});

  factory WordScore.fromJson(Map<String, dynamic> json) {
    return WordScore(
      word: json['word'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
    );
  }
}

class STTResult {
  final String text;
  final String language;
  final List<WordScore> words;

  STTResult({required this.text, required this.language, this.words = const []});

  factory STTResult.fromJson(Map<String, dynamic> json) {
    final wordsRaw = json['words'] as List?;
    return STTResult(
      text: json['text'] as String,
      language: json['language'] as String,
      words: wordsRaw == null
          ? const []
          : wordsRaw.map((e) => WordScore.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ProsodyResult {
  final List<double> pitchContour;
  final List<double> refPitchContour;
  final double score;
  final double dtwDistance;
  final double? rhythmScore;
  final double? stressScore;
  final double? mfccCosineScore;
  final double? compositeScore;
  final double? accentScore;
  final double? speechRateUser;
  final double? speechRateRef;
  final int? pauseCountUser;
  final int? pauseCountRef;
  final String? rhythmFeedback;
  final double? formantScore;
  final double? syllableScore;
  final int? syllableCountUser;
  final int? syllableCountRef;
  final double? voicedRatioScore;
  final double? pitchSlopeScore;
  final double? profileScore;
  final double? nativeDistance;
  final double? russianDistance;
  final Map<String, dynamic>? profileFeatures;
  final double? profileIntonationScore;
  final double? profileRhythmScore;
  final double? profileVoiceScore;
  final double? profileMfccScore;
  final double? profileStressScore;
  final double? profileVowelScore;
  final double? profileSyllableScore;
  final double? profileSlopeScore;

  ProsodyResult({
    required this.pitchContour,
    required this.refPitchContour,
    required this.score,
    required this.dtwDistance,
    this.rhythmScore,
    this.stressScore,
    this.mfccCosineScore,
    this.compositeScore,
    this.accentScore,
    this.speechRateUser,
    this.speechRateRef,
    this.pauseCountUser,
    this.pauseCountRef,
    this.rhythmFeedback,
    this.formantScore,
    this.syllableScore,
    this.syllableCountUser,
    this.syllableCountRef,
    this.voicedRatioScore,
    this.pitchSlopeScore,
    this.profileScore,
    this.nativeDistance,
    this.russianDistance,
    this.profileFeatures,
    this.profileIntonationScore,
    this.profileRhythmScore,
    this.profileVoiceScore,
    this.profileMfccScore,
    this.profileStressScore,
    this.profileVowelScore,
    this.profileSyllableScore,
    this.profileSlopeScore,
  });

  factory ProsodyResult.fromJson(Map<String, dynamic> json) {
    return ProsodyResult(
      pitchContour: (json['pitch_contour'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      refPitchContour: (json['ref_pitch_contour'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      score: (json['score'] as num).toDouble(),
      dtwDistance: (json['dtw_distance'] as num).toDouble(),
      rhythmScore: json['rhythm_score'] != null
          ? (json['rhythm_score'] as num).toDouble()
          : null,
      stressScore: json['stress_score'] != null
          ? (json['stress_score'] as num).toDouble()
          : null,
      mfccCosineScore: json['mfcc_cosine_score'] != null
          ? (json['mfcc_cosine_score'] as num).toDouble()
          : null,
      compositeScore: json['composite_score'] != null
          ? (json['composite_score'] as num).toDouble()
          : null,
      accentScore: json['accent_score'] != null
          ? (json['accent_score'] as num).toDouble()
          : null,
      speechRateUser: json['speech_rate_user'] != null
          ? (json['speech_rate_user'] as num).toDouble()
          : null,
      speechRateRef: json['speech_rate_ref'] != null
          ? (json['speech_rate_ref'] as num).toDouble()
          : null,
      pauseCountUser: json['pause_count_user'] as int?,
      pauseCountRef: json['pause_count_ref'] as int?,
      rhythmFeedback: json['rhythm_feedback'] as String?,
      formantScore: json['formant_score'] != null
          ? (json['formant_score'] as num).toDouble()
          : null,
      syllableScore: json['syllable_score'] != null
          ? (json['syllable_score'] as num).toDouble()
          : null,
      syllableCountUser: json['syllable_count_user'] as int?,
      syllableCountRef: json['syllable_count_ref'] as int?,
      voicedRatioScore: json['voiced_ratio_score'] != null
          ? (json['voiced_ratio_score'] as num).toDouble()
          : null,
      pitchSlopeScore: json['pitch_slope_score'] != null
          ? (json['pitch_slope_score'] as num).toDouble()
          : null,
      profileScore: json['profile_score'] != null
          ? (json['profile_score'] as num).toDouble()
          : null,
      nativeDistance: json['native_distance'] != null
          ? (json['native_distance'] as num).toDouble()
          : null,
      russianDistance: json['russian_distance'] != null
          ? (json['russian_distance'] as num).toDouble()
          : null,
      profileFeatures: json['profile_features'] as Map<String, dynamic>?,
      profileIntonationScore: json['profile_intonation_score'] != null
          ? (json['profile_intonation_score'] as num).toDouble()
          : null,
      profileRhythmScore: json['profile_rhythm_score'] != null
          ? (json['profile_rhythm_score'] as num).toDouble()
          : null,
      profileVoiceScore: json['profile_voice_score'] != null
          ? (json['profile_voice_score'] as num).toDouble()
          : null,
      profileMfccScore: json['profile_mfcc_score'] != null
          ? (json['profile_mfcc_score'] as num).toDouble()
          : null,
      profileStressScore: json['profile_stress_score'] != null
          ? (json['profile_stress_score'] as num).toDouble()
          : null,
      profileVowelScore: json['profile_vowel_score'] != null
          ? (json['profile_vowel_score'] as num).toDouble()
          : null,
      profileSyllableScore: json['profile_syllable_score'] != null
          ? (json['profile_syllable_score'] as num).toDouble()
          : null,
      profileSlopeScore: json['profile_slope_score'] != null
          ? (json['profile_slope_score'] as num).toDouble()
          : null,
    );
  }
}

class ChatResult {
  final String reply;
  final String? hint;
  final String? hintRu;

  ChatResult({required this.reply, this.hint, this.hintRu});

  factory ChatResult.fromJson(Map<String, dynamic> json) {
    return ChatResult(
      reply: json['reply'] as String,
      hint: json['hint'] as String?,
      hintRu: json['hint_ru'] as String?,
    );
  }
}

class ProcessResult {
  final STTResult stt;
  final ProsodyResult? prosody;
  final ChatResult chat;
  final double? totalScore;
  final String? prosodyFeedback;

  ProcessResult({
    required this.stt,
    this.prosody,
    required this.chat,
    this.totalScore,
    this.prosodyFeedback,
  });

  factory ProcessResult.fromJson(Map<String, dynamic> json) {
    return ProcessResult(
      stt: STTResult.fromJson(json['stt'] as Map<String, dynamic>),
      prosody: json['prosody'] != null
          ? ProsodyResult.fromJson(json['prosody'] as Map<String, dynamic>)
          : null,
      chat: ChatResult.fromJson(json['chat'] as Map<String, dynamic>),
      totalScore: json['total_score'] != null
          ? (json['total_score'] as num).toDouble()
          : null,
      prosodyFeedback: json['prosody_feedback'] as String?,
    );
  }
}
