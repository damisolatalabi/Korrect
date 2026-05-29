import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/scenario_model.dart';
import '../services/progress_service.dart';
import '../utils/pronunciation_guidance.dart';
import '../utils/score_band.dart';
import 'home_screen.dart';
import 'word_drill_screen.dart';

class ResultScreen extends StatefulWidget {
  final Scenario scenario;
  final double? totalScore;
  final int turnCount;
  final double? profileScore;
  final double? intonationScore;
  final double? rhythmScore;
  final double? mfccScore;
  final double? voiceScore;
  final double? stressScore;
  final double? vowelScore;
  final double? syllableScore;
  final double? slopeScore;
  final List<WordRecord> wordRecords;

  ResultScreen({
    super.key,
    required this.scenario,
    required this.totalScore,
    required this.turnCount,
    this.profileScore,
    this.intonationScore,
    this.rhythmScore,
    this.mfccScore,
    this.voiceScore,
    this.stressScore,
    this.vowelScore,
    this.syllableScore,
    this.slopeScore,
    this.wordRecords = const [],
  });

  double? get _pronunciationScore {
    final values = [mfccScore, voiceScore].whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<MapEntry<String, double>> get _majorScoreItems => [
        if (profileScore != null) MapEntry('한국어 근접도', profileScore!),
        if (intonationScore != null) MapEntry('억양', intonationScore!),
        if (rhythmScore != null) MapEntry('리듬', rhythmScore!),
        if (_pronunciationScore != null) MapEntry('발음', _pronunciationScore!),
      ];

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.totalScore != null && widget.totalScore! >= 80) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _emoji {
    if (widget.totalScore == null) return '🙂';
    if (widget.totalScore! >= 80) return '🎉';
    if (widget.totalScore! >= 60) return '👍';
    return '💪';
  }

  String get _message {
    if (widget.totalScore == null) return '오늘도 한 걸음 더 연습했어요.';
    if (widget.totalScore! >= 80) return '훌륭해요! 한국어 발화가 많이 자연스러워졌어요.';
    if (widget.totalScore! >= 60) return '좋아요. 조금만 더 다듬으면 더 자연스러워질 거예요.';
    return '괜찮아요. 꾸준히 연습하면 분명히 좋아질 거예요.';
  }


  // ignore: unused_element
  List<MapEntry<String, double>> get _scoreItems => [
        if (widget.profileScore != null) MapEntry('한국어 근접도', widget.profileScore!),
        if (widget.intonationScore != null) MapEntry('억양', widget.intonationScore!),
        if (widget.rhythmScore != null) MapEntry('리듬', widget.rhythmScore!),
        if (widget.mfccScore != null) MapEntry('음색', widget.mfccScore!),
        if (widget.voiceScore != null) MapEntry('발성', widget.voiceScore!),
        if (widget.stressScore != null) MapEntry('강세', widget.stressScore!),
        if (widget.vowelScore != null) MapEntry('모음', widget.vowelScore!),
        if (widget.syllableScore != null) MapEntry('음절', widget.syllableScore!),
        if (widget.slopeScore != null) MapEntry('기울기', widget.slopeScore!),
      ];

  @override
  Widget build(BuildContext context) {
    final scenarioEmoji = AppConstants.scenarioEmoji[widget.scenario.id] ?? '🎯';
    final practiceGuides = buildPracticeGuides(widget.wordRecords);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(AppConstants.bgColor),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(_emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  const Text(
                    '학습 완료!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$scenarioEmoji ${widget.scenario.title} 연습',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '종합 수준',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scoreBandLabel(widget.totalScore),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: scoreBandColor(widget.totalScore),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _message,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _StatItem(label: '연습 턴 수', value: '${widget.turnCount}회'),
                        if (widget._majorScoreItems.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '세부 점수 평균',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...widget._majorScoreItems.map(
                            (entry) => _ResultScoreBar(label: entry.key, score: entry.value),
                          ),
                        ],
                        if (practiceGuides.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          _PracticeGuideSection(
                            guides: practiceGuides,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.primaryColor),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '다른 연습 하기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '다시 연습하기',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.red,
              Colors.green,
              Colors.blue,
              Colors.yellow,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}

class _PracticeGuideSection extends StatelessWidget {
  final List<WordPracticeGuide> guides;

  const _PracticeGuideSection({
    required this.guides,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '교정 가이드',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        ...guides.map((guide) => _PracticeGuideCard(
              guide: guide,
            )),
      ],
    );
  }
}

class _PracticeGuideCard extends StatelessWidget {
  final WordPracticeGuide guide;

  const _PracticeGuideCard({
    required this.guide,
  });

  @override
  Widget build(BuildContext context) {
    final score = guide.score;
    final scoreText = score == null || score <= 0 ? '인식 불안정' : scoreBandLabel(score);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${guide.word}" 다시 3번 따라 말하기 ($scoreText)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...guide.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${tip.title}: ${tip.guide}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordDrillScreen(
                    targetWord: guide.word,
                  ),
                ),
              ),
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('다시 연습'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }
}

class _ResultScoreBar extends StatelessWidget {
  final String label;
  final double score;

  const _ResultScoreBar({required this.label, required this.score});

  Color get _barColor {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              scoreBandLabel(score),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: scoreBandColor(score),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
