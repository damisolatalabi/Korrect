import 'package:flutter/material.dart';
import '../utils/ref_player.dart';
import '../constants.dart';
import '../models/scenario_model.dart';
import '../models/process_result.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/record_button.dart';
import '../widgets/pitch_chart.dart';
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
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  bool _isLoading = false;
  int _turnIndex = 0;
  double _totalScore = 0;
  int _scoreCount = 0;
  double _rhythmTotal = 0;
  double _stressTotal = 0;
  double _mfccTotal = 0;
  int _subScoreCount = 0;

  static const int _maxTurns = 5;

  // Store last hint and last reference audio URL for replay buttons
  String? _lastHint;
  String? _lastRefAudioUrl;

  @override
  void initState() {
    super.initState();
    _loadOpeningMessage();
  }

  @override
  void dispose() {
    AudioService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOpeningMessage() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getOpeningMessage(widget.scenario.id);
      final reply = data['reply'] as String;
      final hint = data['hint'] as String?;
      setState(() {
        _messages.add(_ChatMessage(
          text: reply,
          isAi: true,
          hint: hint,
        ));
        _history.add({'role': 'model', 'text': reply});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
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
        _showSnackBar('마이크 권한이 필요해요!');
        return;
      }
      await AudioService.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar('녹음 시작 실패: $e');
    }
  }

  Future<void> _stopAndProcess() async {
    setState(() {
      _isRecording = false;
      _isLoading = true;
    });

    final audio = await AudioService.stopRecording();
    if (audio == null) {
      setState(() => _isLoading = false);
      _showSnackBar('녹음 파일을 찾을 수 없어요.');
      return;
    }
    final size = audio.bytes?.length ?? await audio.file!.length();
    _showSnackBar('녹음 파일 크기: ${size}B');

    try {
      final result = await ApiService.processTurn(
        scenarioId: widget.scenario.id,
        audio: audio,
        history: List.from(_history),
        turnIndex: _turnIndex,
      );

      _handleResult(result);
    } catch (e) {
      _showSnackBar('처리 중 오류가 발생했어요: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleResult(ProcessResult result) {
    setState(() {
      final sttText = result.stt.text.trim();
      final refAudioUrl = sttText.isNotEmpty
          ? '${AppConstants.baseUrl}/api/tts?text=${Uri.encodeComponent(sttText)}'
          : null;

      // Store for replay buttons
      _lastRefAudioUrl = refAudioUrl;

      _messages.add(_ChatMessage(
        text: result.stt.text.isEmpty ? '(알아듣지 못했어요)' : result.stt.text,
        isAi: false,
        prosody: result.prosody,
        score: result.totalScore,
        prosodyFeedback: result.prosodyFeedback,
        refAudioUrl: refAudioUrl,
      ));
    });

    if (result.totalScore != null) {
      _totalScore += result.totalScore!;
      _scoreCount++;
    }
    final p = result.prosody;
    if (p != null &&
        p.rhythmScore != null &&
        p.stressScore != null &&
        p.mfccCosineScore != null) {
      _rhythmTotal += p.rhythmScore!;
      _stressTotal += p.stressScore!;
      _mfccTotal += p.mfccCosineScore!;
      _subScoreCount++;
    }

    _history.add({'role': 'user', 'text': result.stt.text});

    setState(() {
      final reply = result.chat.reply;
      final hint = result.chat.hint;

      // Store last hint for replay button
      _lastHint = hint;

      _messages.add(_ChatMessage(
        text: reply,
        isAi: true,
        hint: hint,
      ));
      _history.add({'role': 'model', 'text': reply});
      _turnIndex++;
    });

    _scrollToBottom();

    if (_turnIndex >= _maxTurns) {
      Future.delayed(const Duration(milliseconds: 800), () {
        final avgScore = _scoreCount > 0 ? _totalScore / _scoreCount : null;
        final avgRhythm =
            _subScoreCount > 0 ? _rhythmTotal / _subScoreCount : null;
        final avgStress =
            _subScoreCount > 0 ? _stressTotal / _subScoreCount : null;
        final avgMfcc = _subScoreCount > 0 ? _mfccTotal / _subScoreCount : null;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              scenario: widget.scenario,
              totalScore: avgScore,
              turnCount: _turnIndex,
              rhythmScore: avgRhythm,
              stressScore: avgStress,
              mfccScore: avgMfcc,
            ),
          ),
        );
      });
    }
  }

  void _showHint() {
    if (_lastHint != null) {
      _showSnackBar('💡 힌트: $_lastHint');
    } else {
      _showSnackBar('💡 아직 힌트가 없어요. 먼저 AI와 대화해보세요!');
    }
  }

  void _replayReferenceAudio() {
    if (_lastRefAudioUrl != null) {
      _showSnackBar('🔊 원어민 발음을 재생합니다...');
    } else {
      _showSnackBar('🔊 아직 원어민 발음이 없어요. 먼저 말해보세요!');
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
    final emoji = AppConstants.scenarioEmoji[widget.scenario.id] ?? '💬';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('연습을 그만할까요?'),
              content: const Text('지금 나가면 진행 상황이 저장되지 않아요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('계속 연습'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('나가기'),
                ),
              ],
            ),
          );
          if (shouldPop == true) {
            Navigator.pop(context);
          }
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_turnIndex/$_maxTurns',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
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
                                    : Colors.white.withOpacity(0.35),
                              ),
                            )),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                  if (_isRecording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '말하고 있어요... 버튼을 눌러서 멈춰요',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '버튼을 눌러서 말해봐요!',
                        style: TextStyle(color: Color(0xFFFF9500), fontSize: 16),
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
                                color: const Color(0xFFFFD700), width: 2),
                          ),
                          child: const Center(
                              child: Text('💡', style: TextStyle(fontSize: 20))),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                                color: const Color(0xFFFFD700), width: 2),
                          ),
                          child: const Center(
                              child: Text('🔊', style: TextStyle(fontSize: 20))),
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
  final ProsodyResult? prosody;
  final double? score;
  final String? prosodyFeedback;
  final String? refAudioUrl;

  _ChatMessage({
    required this.text,
    required this.isAi,
    this.hint,
    this.prosody,
    this.score,
    this.prosodyFeedback,
    this.refAudioUrl,
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
  RefPlayer? _player;
  bool _isPlaying = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.message.refAudioUrl!;
    if (_isPlaying) {
      await _player?.stop();
      setState(() => _isPlaying = false);
      return;
    }
    _player ??= RefPlayer();
    try {
      await _player!.play(url);
      setState(() => _isPlaying = true);
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
                  child: Text('AI',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
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
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
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
          if (isAi && widget.message.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 14)),
                    Text(
                      '"${widget.message.hint}"',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isAi && widget.message.prosodyFeedback != null) ...[
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
                  const Text('🗣️ ', style: TextStyle(fontSize: 14)),
                  Flexible(
                    child: Text(
                      widget.message.prosodyFeedback!,
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
                onPressed: _togglePlay,
                icon: Icon(
                  _isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  size: 18,
                  color: const Color(0xFFFF9500),
                ),
                label: Text(
                  _isPlaying ? '멈추기' : '원어민 발음 듣기',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFFFF9500)),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScoreBreakdown(prosody: widget.message.prosody!),
                    const SizedBox(height: 12),
                    PitchChart(
                      userPitch: widget.message.prosody!.pitchContour,
                      refPitch: widget.message.prosody!.refPitchContour,
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

  Color get _color {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${score.toInt()}점',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final ProsodyResult prosody;

  const _ScoreBreakdown({required this.prosody});

  @override
  Widget build(BuildContext context) {
    if (prosody.compositeScore == null) return const SizedBox.shrink();

    final items = <MapEntry<String, double>>[
      MapEntry('억양', prosody.score),
      if (prosody.rhythmScore != null) MapEntry('리듬', prosody.rhythmScore!),
      if (prosody.stressScore != null) MapEntry('강세', prosody.stressScore!),
      if (prosody.mfccCosineScore != null)
        MapEntry('음색', prosody.mfccCosineScore!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '점수 세부',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        ...items.map((e) => _ScoreBar(label: e.key, score: e.value)),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;

  const _ScoreBar({required this.label, required this.score});

  Color get _barColor {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_barColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              '${score.toInt()}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}