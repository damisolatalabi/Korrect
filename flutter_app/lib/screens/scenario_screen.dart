import 'package:flutter/material.dart';
import '../utils/ref_player.dart';
import '../constants.dart';
import '../models/scenario_model.dart';
import '../models/process_result.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../widgets/record_button.dart';
import '../widgets/pitch_chart.dart';
import '../utils/score_band.dart';
import 'progress_screen.dart';
import 'result_screen.dart';

class ScenarioScreen extends StatefulWidget {
  final Scenario scenario;

  const ScenarioScreen({super.key, required this.scenario});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  final List<WordRecord> _wordRecords = [];
  final List<TurnRecord> _turnRecords = [];
  final ScrollController _scrollController = ScrollController();

  RefPlayer? _referencePlayer;
  bool _isReferencePlaying = false;
  bool _isRecording = false;
  bool _isLoading = false;
  int _turnIndex = 0;
  DateTime? _recordingStartTime;
  double _totalScore = 0;
  int _scoreCount = 0;
  double _profileTotal = 0;
  double _intonationTotal = 0;
  double _rhythmTotal = 0;
  double _mfccTotal = 0;
  double _voiceTotal = 0;
  double _stressTotal = 0;
  double _vowelTotal = 0;
  double _syllableTotal = 0;
  double _slopeTotal = 0;
  int _profileScoreCount = 0;
  int _intonationCount = 0;
  int _rhythmCount = 0;
  int _mfccCount = 0;
  int _voiceCount = 0;
  int _stressCount = 0;
  int _vowelCount = 0;
  int _syllableCount = 0;
  int _slopeCount = 0;
  String? _lastHint;
  String? _lastRefAudioUrl;
  final String _sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  static const int _maxTurns = 4;

  static String _firstSentence(String text) {
    return text.trim().split('\n').first.trim();
  }

  void _accumulateMetric(double? value, void Function(double) add, void Function() bump) {
    if (value == null) return;
    add(value);
    bump();
  }

  SessionRecord? _buildSessionRecord() {
    if (_turnIndex == 0) {
      return null;
    }

    return SessionRecord(
      sessionId: _sessionId,
      scenarioId: widget.scenario.id,
      scenarioTitle: widget.scenario.title,
      totalScore: _scoreCount > 0 ? _totalScore / _scoreCount : null,
      profileScore: _profileScoreCount > 0 ? _profileTotal / _profileScoreCount : null,
      intonationScore: _intonationCount > 0 ? _intonationTotal / _intonationCount : null,
      rhythmScore: _rhythmCount > 0 ? _rhythmTotal / _rhythmCount : null,
      mfccScore: _mfccCount > 0 ? _mfccTotal / _mfccCount : null,
      voiceScore: _voiceCount > 0 ? _voiceTotal / _voiceCount : null,
      stressScore: _stressCount > 0 ? _stressTotal / _stressCount : null,
      vowelScore: _vowelCount > 0 ? _vowelTotal / _vowelCount : null,
      syllableScore: _syllableCount > 0 ? _syllableTotal / _syllableCount : null,
      slopeScore: _slopeCount > 0 ? _slopeTotal / _slopeCount : null,
      wordRecords: List<WordRecord>.from(_wordRecords),
      turnRecords: List<TurnRecord>.from(_turnRecords),
      turnCount: _turnIndex,
      date: DateTime.now(),
    );
  }

  // 매 턴 호출. 같은 _sessionId 기록을 갱신하므로 중복 저장되지 않는다.
  Future<void> _persistProgress() async {
    final record = _buildSessionRecord();
    if (record == null) {
      return;
    }
    await ProgressService.saveOrUpdateSession(record);
  }

  Future<void> _openProgressScreen() async {
    await _persistProgress();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgressScreen()),
    );
  }

  Future<void> _openResultScreen() async {
    final record = _buildSessionRecord();
    if (record == null) {
      return;
    }
    await _persistProgress();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          scenario: widget.scenario,
          totalScore: record.totalScore,
          turnCount: record.turnCount,
          profileScore: record.profileScore,
          intonationScore: record.intonationScore,
          rhythmScore: record.rhythmScore,
          mfccScore: record.mfccScore,
          voiceScore: record.voiceScore,
          stressScore: record.stressScore,
          vowelScore: record.vowelScore,
          syllableScore: record.syllableScore,
          slopeScore: record.slopeScore,
          wordRecords: record.wordRecords,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOpeningMessage();
  }

  @override
  void dispose() {
    AudioService.dispose();
    _referencePlayer?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOpeningMessage() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getOpeningMessage(widget.scenario.id);
      final reply = data['reply'] as String;
      final hint = data['hint'] as String?;
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: reply,
          isAi: true,
          hint: hint,
          ttsUrl: '${AppConstants.baseUrl}/api/tts?text=${Uri.encodeComponent(_firstSentence(reply))}',
        ));
        _history.add({'role': 'model', 'text': reply});
        _lastHint = hint;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await AudioService.hasPermission();
      if (!hasPermission) {
        _showSnackBar('마이크 권한이 필요해요.');
        return;
      }
      await AudioService.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });
    } catch (e) {
      _showSnackBar('녹음 시작에 실패했어요: $e');
    }
  }

  Future<void> _stopAndProcess() async {
    if (_recordingStartTime != null &&
        DateTime.now().difference(_recordingStartTime!).inMilliseconds < 1000) {
      _showSnackBar('1초 이상 말해 주세요.');
      return;
    }

    setState(() {
      _isRecording = false;
      _isLoading = true;
    });

    final audio = await AudioService.stopRecording();
    if (audio == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('녹음 파일을 찾을 수 없어요.');
      return;
    }

    final size = audio.bytes?.length ?? await audio.file!.length();
    if (size < 4096) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('녹음이 너무 짧거나 소리가 작아요.');
      return;
    }

    try {
      final result = await ApiService.processTurn(
        scenarioId: widget.scenario.id,
        audio: audio,
        history: List.from(_history),
        turnIndex: _turnIndex,
      );
      if (!mounted) return;
      _handleResult(result);
    } catch (e) {
      _showSnackBar('처리 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleResult(ProcessResult result) {
    final p = result.prosody;
    // 신호가 또렷하지 않으면(소음·무음·너무 짧음) 점수를 보류하고 집계에서 제외한다.
    final reliable = p?.reliable ?? true;
    final scoreForSummary = result.prosody?.profileScore ?? result.totalScore;

    setState(() {
      final sttText = result.stt.text.trim();
      final refAudioUrl = sttText.isNotEmpty
          ? '${AppConstants.baseUrl}/api/tts?text=${Uri.encodeComponent(sttText)}'
          : null;

      _lastRefAudioUrl = refAudioUrl;

      _messages.add(_ChatMessage(
        text: result.stt.text.isEmpty ? '(알아듣지 못했어요)' : result.stt.text,
        isAi: false,
        prosody: reliable ? result.prosody : null,
        score: reliable ? scoreForSummary : null,
        prosodyFeedback: reliable ? result.prosodyFeedback : null,
        lowSignal: !reliable,
        refAudioUrl: refAudioUrl,
        words: result.stt.words,
      ));
    });

    // 신뢰할 수 없는 턴은 점수/세부지표를 누적하지 않는다 (평균 오염 방지).
    if (reliable) {
      if (scoreForSummary != null) {
        _totalScore += scoreForSummary;
        _scoreCount++;
      }

      final currentTurnWords = <WordRecord>[];
      for (final word in result.stt.words) {
        final text = word.word.trim();
        if (text.isEmpty) continue;
        final record = WordRecord(
          word: text,
          score: word.score,
          vowelScore: p?.profileVowelScore, // 발화 단위 게이트
          formantF1: word.formantF1, // 단어 단위 포먼트
          formantF2: word.formantF2,
        );
        _wordRecords.add(record);
        currentTurnWords.add(record);
      }
      _turnRecords.add(TurnRecord(
        turnNumber: _turnIndex + 1,
        text: result.stt.text.trim(),
        totalScore: scoreForSummary,
        profileScore: p?.profileScore,
        intonationScore: p?.profileIntonationScore,
        rhythmScore: p?.profileRhythmScore,
        mfccScore: p?.profileMfccScore,
        voiceScore: p?.profileVoiceScore,
        vowelScore: p?.profileVowelScore,
        wordRecords: currentTurnWords,
        date: DateTime.now(),
      ));
      if (p?.profileScore != null) {
        _profileTotal += p!.profileScore!;
        _profileScoreCount++;
      }
      _accumulateMetric(p?.profileIntonationScore, (v) => _intonationTotal += v, () => _intonationCount++);
      _accumulateMetric(p?.profileRhythmScore, (v) => _rhythmTotal += v, () => _rhythmCount++);
      _accumulateMetric(p?.profileMfccScore, (v) => _mfccTotal += v, () => _mfccCount++);
      _accumulateMetric(p?.profileVoiceScore, (v) => _voiceTotal += v, () => _voiceCount++);
      _accumulateMetric(p?.profileStressScore, (v) => _stressTotal += v, () => _stressCount++);
      _accumulateMetric(p?.profileVowelScore, (v) => _vowelTotal += v, () => _vowelCount++);
      _accumulateMetric(p?.profileSyllableScore, (v) => _syllableTotal += v, () => _syllableCount++);
      _accumulateMetric(p?.profileSlopeScore, (v) => _slopeTotal += v, () => _slopeCount++);
    }

    _history.add({'role': 'user', 'text': result.stt.text});

    setState(() {
      _messages.add(_ChatMessage(
        text: result.chat.reply,
        isAi: true,
        hint: result.chat.hint,
        hintRu: result.chat.hintRu,
        ttsUrl: '${AppConstants.baseUrl}/api/tts?text=${Uri.encodeComponent(_firstSentence(result.chat.reply))}',
      ));
      _lastHint = result.chat.hintRu ?? result.chat.hint;
      _history.add({'role': 'model', 'text': result.chat.reply});
      _turnIndex++;
    });

    _scrollToBottom();

    // 턴이 끝날 때마다 저장해서, 중간에 나가도 기록이 남도록 한다.
    _persistProgress();

  }

  void _showHint() {
    if (_lastHint == null || _lastHint!.isEmpty) {
      _showSnackBar('아직 힌트가 없어요.');
      return;
    }
    _showSnackBar(_lastHint!);
  }

  Future<void> _replayReferenceAudio() async {
    final url = _lastRefAudioUrl;
    if (url == null || url.isEmpty) {
      _showSnackBar('아직 원어민 발음이 없어요.');
      return;
    }

    _referencePlayer ??= RefPlayer();
    if (_isReferencePlaying) {
      await _referencePlayer!.stop();
      if (mounted) {
        setState(() => _isReferencePlaying = false);
      }
      return;
    }

    try {
      setState(() => _isReferencePlaying = true);
      await _referencePlayer!.play(url);
      _referencePlayer!.onComplete.listen((_) {
        if (mounted) {
          setState(() => _isReferencePlaying = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isReferencePlaying = false);
      }
      _showSnackBar('재생에 실패했어요: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = AppConstants.scenarioEmoji[widget.scenario.id] ?? '?';
    final isComplete = _turnIndex >= _maxTurns;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('연습을 그만할까요?'),
            content: const Text('지금 나가면 진행 상황이 저장되지 않아요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('계속 연습'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('나가기', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await _persistProgress();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          title: Text(
            '$emoji ${widget.scenario.title}',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
              tooltip: '학습 기록',
              onPressed: _openProgressScreen,
            ),
            Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_turnIndex/$_maxTurns',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    children: List.generate(
                      _maxTurns,
                      (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _turnIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF9500),
                  Color(0xFFFFC107),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('처리 중...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFE8E0C8),
                    blurRadius: 0,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: _openProgressScreen,
                      icon: const Icon(Icons.bar_chart_rounded, size: 18),
                      label: const Text('학습 기록 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9500),
                        side: const BorderSide(color: Color(0xFFFFC107)),
                        backgroundColor: const Color(0xFFFFF9E6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isComplete
                          ? '마지막 연습 결과를 확인한 뒤 결과를 볼 수 있어요.'
                          : _isRecording
                          ? '말하고 있어요... 버튼을 눌러서 멈춰요'
                          : '버튼을 눌러서 말해봐요!',
                      style: TextStyle(
                        color: _isRecording ? Colors.red : const Color(0xFFFF9500),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _showHint,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFF3CD),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 22,
                              color: Color(0xFFFF9500),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (isComplete)
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _openResultScreen,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('결과 보기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        )
                      else
                        RecordButton(
                          isRecording: _isRecording,
                          isLoading: _isLoading,
                          onTap: _isLoading ? () {} : _toggleRecording,
                        ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _replayReferenceAudio,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFF3CD),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _isReferencePlaying
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              size: 22,
                              color: const Color(0xFFFF9500),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  final String? hint;
  final String? hintRu;
  final ProsodyResult? prosody;
  final double? score;
  final String? prosodyFeedback;
  final String? refAudioUrl;
  final String? ttsUrl;
  final List<WordScore> words;
  final bool lowSignal;

  _ChatMessage({
    required this.text,
    required this.isAi,
    this.hint,
    this.hintRu,
    this.prosody,
    this.score,
    this.prosodyFeedback,
    this.refAudioUrl,
    this.ttsUrl,
    this.words = const [],
    this.lowSignal = false,
  });
}

class _MessageBubble extends StatefulWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showPitch = false;
  bool _showHintRu = false;
  RefPlayer? _player;
  bool _isPlaying = false;

  // 점수가 있으면 점수 구간에 맞춘 격려 문구를, 없으면 백엔드 피드백을 사용한다.
  String? get _feedbackText {
    final score = widget.message.score;
    if (score != null) return scoreEncouragement(score);
    return widget.message.prosodyFeedback;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String url) async {
    if (_isPlaying) {
      await _player?.stop();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }

    _player ??= RefPlayer();
    try {
      await _player!.play(url);
      if (mounted) {
        setState(() => _isPlaying = true);
      }
      _player!.onComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAi = widget.message.isAi;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment:
                isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isAi) ...[
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFF9500),
                  child: Text(
                    'AI',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isAi ? Colors.white : const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: !isAi && widget.message.words.isNotEmpty
                      ? _ColoredWordsText(words: widget.message.words)
                      : Text(
                          widget.message.text,
                          style: TextStyle(
                            color: isAi ? Colors.black87 : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              if (!isAi && widget.message.score != null) ...[
                const SizedBox(width: 8),
                _ScoreBadge(score: widget.message.score!),
              ],
            ],
          ),
          if (!isAi && widget.message.lowSignal) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_off_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '소리가 약해서 점수를 못 쟀어요. 또렷하게 다시 말해줄래요?',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isAi && widget.message.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: GestureDetector(
                onTap: widget.message.hintRu != null
                    ? () => setState(() => _showHintRu = !_showHintRu)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: Color(0xFFFF9500),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _showHintRu && widget.message.hintRu != null
                              ? '"${widget.message.hintRu}"'
                              : '"${widget.message.hint}"',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber[900],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (isAi && widget.message.ttsUrl != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: TextButton.icon(
                onPressed: () => _togglePlay(widget.message.ttsUrl!),
                icon: Icon(
                  _isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                label: Text(
                  _isPlaying ? '멈추기' : '들어봐요',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
          // 점수와 '일치하는' 격려 문구만 보여준다 (배지가 낮은데 칭찬하는 모순 방지).
          // 점수가 없으면(보류/실패) 백엔드 피드백을 그대로 사용.
          if (!isAi && _feedbackText != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.feedback_outlined,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _feedbackText!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isAi && widget.message.refAudioUrl != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _togglePlay(widget.message.refAudioUrl!),
                icon: Icon(
                  _isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                  size: 18,
                  color: const Color(0xFFFF9500),
                ),
                label: Text(
                  _isPlaying ? '멈추기' : '원어민 발음 듣기',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF9500),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
          if (!isAi && widget.message.prosody != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showPitch = !_showPitch),
                icon: Icon(
                  _showPitch ? Icons.expand_less : Icons.show_chart,
                  size: 18,
                ),
                label: Text(
                  _showPitch ? '분석 닫기' : '발음 분석 보기',
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ),
            if (_showPitch)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MajorMetricBreakdown(prosody: widget.message.prosody!),
                    const SizedBox(height: 12),
                    PitchChart(
                      userPitch: widget.message.prosody!.pitchContour,
                      refPitch: widget.message.prosody!.refPitchContour,
                      refAudioUrl: widget.message.refAudioUrl,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scoreBandColor(score),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        scoreBandLabel(score),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ScoreBreakdown extends StatelessWidget {
  final ProsodyResult prosody;

  const _ScoreBreakdown({required this.prosody});

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, double>>[
      if (prosody.profileScore != null) MapEntry('한국어 근접도', prosody.profileScore!),
      if (prosody.profileIntonationScore != null) MapEntry('억양', prosody.profileIntonationScore!),
      if (prosody.profileRhythmScore != null) MapEntry('리듬', prosody.profileRhythmScore!),
      if (prosody.profileMfccScore != null) MapEntry('음색', prosody.profileMfccScore!),
      if (prosody.profileVoiceScore != null) MapEntry('발성', prosody.profileVoiceScore!),
    ];

    final hasRhythmDetail = prosody.profileScore == null &&
        prosody.speechRateUser != null &&
        prosody.speechRateRef != null &&
        prosody.pauseCountUser != null &&
        prosody.pauseCountRef != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '점수 세부',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((e) => _ScoreBar(label: e.key, score: e.value)),
        if (hasRhythmDetail) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text(
            '리듬 세부',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          _RhythmDetailRow(
            label: '속도',
            userValue: prosody.speechRateUser!.toStringAsFixed(1),
            refValue: prosody.speechRateRef!.toStringAsFixed(1),
          ),
          _RhythmDetailRow(
            label: '멈춤',
            userValue: '${prosody.pauseCountUser}',
            refValue: '${prosody.pauseCountRef}',
          ),
          if (prosody.rhythmFeedback != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 14,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      prosody.rhythmFeedback!,
                      style: TextStyle(fontSize: 11, color: Colors.purple[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RhythmDetailRow extends StatelessWidget {
  final String label;
  final String userValue;
  final String refValue;

  const _RhythmDetailRow({
    required this.label,
    required this.userValue,
    required this.refValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              '나: $userValue',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '원어민: $refValue',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _MajorMetricBreakdown extends StatelessWidget {
  final ProsodyResult prosody;

  const _MajorMetricBreakdown({required this.prosody});

  double? get _pronunciationScore {
    final values = [
      prosody.profileMfccScore,
      prosody.profileVoiceScore,
    ].whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, double>>[
      if (prosody.profileScore != null) MapEntry('한국어 근접도', prosody.profileScore!),
      if (prosody.profileIntonationScore != null) MapEntry('억양', prosody.profileIntonationScore!),
      if (prosody.profileRhythmScore != null) MapEntry('리듬', prosody.profileRhythmScore!),
      if (_pronunciationScore != null) MapEntry('발음', _pronunciationScore!),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주요 지표',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((entry) => _ScoreBar(label: entry.key, score: entry.value)),
      ],
    );
  }
}

// ignore: unused_element
class _NineMetricBreakdown extends StatelessWidget {
  final ProsodyResult prosody;

  const _NineMetricBreakdown({required this.prosody});

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, double>>[
      if (prosody.profileScore != null) MapEntry('한국어 근접도', prosody.profileScore!),
      if (prosody.profileIntonationScore != null) MapEntry('억양', prosody.profileIntonationScore!),
      if (prosody.profileRhythmScore != null) MapEntry('리듬', prosody.profileRhythmScore!),
      if (prosody.profileMfccScore != null) MapEntry('음색', prosody.profileMfccScore!),
      if (prosody.profileVoiceScore != null) MapEntry('발성', prosody.profileVoiceScore!),
      if (prosody.profileStressScore != null) MapEntry('강세', prosody.profileStressScore!),
      if (prosody.profileVowelScore != null) MapEntry('모음', prosody.profileVowelScore!),
      if (prosody.profileSyllableScore != null) MapEntry('음절', prosody.profileSyllableScore!),
      if (prosody.profileSlopeScore != null) MapEntry('기울기', prosody.profileSlopeScore!),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '점수 세부',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((entry) => _ScoreBar(label: entry.key, score: entry.value)),
      ],
    );
  }
}

class _ColoredWordsText extends StatelessWidget {
  final List<WordScore> words;

  const _ColoredWordsText({required this.words});

  Color _wordColor(double? score) {
    if (score == null) return Colors.white;
    if (score >= 70) return Colors.greenAccent[100]!;
    if (score >= 40) return Colors.amberAccent[100]!;
    return Colors.redAccent[100]!;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          for (final w in words)
            TextSpan(
              text: '${w.word} ',
              style: TextStyle(
                color: _wordColor(w.score),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;

  const _ScoreBar({required this.label, required this.score});

  Color get _barColor {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_barColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: Text(
              scoreBandLabel(score),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scoreBandColor(score),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
