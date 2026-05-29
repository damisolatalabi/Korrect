import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/process_result.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../utils/phoneme_diagnosis.dart';
import '../utils/score_band.dart';
import '../widgets/record_button.dart';

class WordDrillScreen extends StatefulWidget {
  final String targetWord;

  const WordDrillScreen({
    super.key,
    required this.targetWord,
  });

  @override
  State<WordDrillScreen> createState() => _WordDrillScreenState();
}

class _WordDrillScreenState extends State<WordDrillScreen> {
  final List<_DrillAttempt> _attempts = [];
  bool _isRecording = false;
  bool _isLoading = false;
  DateTime? _recordingStartTime;

  static const int _maxAttempts = 3;

  double? get _bestScore {
    if (_attempts.isEmpty) return null;
    return _attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _toggleRecording() async {
    if (_attempts.length >= _maxAttempts || _isLoading) return;
    if (_isRecording) {
      await _stopAndAnalyze();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
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
  }

  Future<void> _stopAndAnalyze() async {
    if (_recordingStartTime != null &&
        DateTime.now().difference(_recordingStartTime!).inMilliseconds < 700) {
      _showSnackBar('조금 더 길게 말해보세요.');
      return;
    }

    setState(() {
      _isRecording = false;
      _isLoading = true;
    });

    final audio = await AudioService.stopRecording();
    if (audio == null) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('녹음 파일을 찾을 수 없어요.');
      return;
    }

    try {
      final result = await ApiService.analyzeDrill(audio: audio);
      if (!mounted) return;
      // 신호가 또렷하지 않으면 시도로 치지 않고 다시 녹음하도록 안내.
      if (result.prosody?.reliable == false) {
        _showSnackBar('소리가 약해요. 또렷하게 다시 말해볼까요?');
        return;
      }
      setState(() {
        _attempts.add(_DrillAttempt.fromResult(result, widget.targetWord));
      });
      // STT가 음소 혼동을 잡아내면 약한 음소로 누적(세션 넘어 저장).
      final confusion =
          diagnoseConfusion(widget.targetWord, result.stt.text);
      if (confusion?.phoneme != null) {
        ProgressService.recordWeakPhoneme(confusion!.phoneme!);
      }
    } catch (e) {
      _showSnackBar('분석 중 오류가 발생했어요. $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    AudioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _maxAttempts - _attempts.length;
    return Scaffold(
      backgroundColor: const Color(AppConstants.bgColor),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColor),
        title: const Text(
          '단어 반복 연습',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '이 단어를 또박또박 따라 말해보세요',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.targetWord,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF9500),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bestScore == null
                          ? '남은 연습 $remaining회'
                          : '이번 최고: ${scoreBandLabel(_bestScore)} · 남은 연습 $remaining회',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _attempts.isEmpty
                    ? const Center(
                        child: Text(
                          '녹음 버튼을 눌러 첫 번째 연습을 시작해보세요.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _attempts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final attempt = _attempts[index];
                          return _AttemptCard(
                            attempt: attempt,
                            index: index + 1,
                            firstScore: index > 0 ? _attempts.first.score : null,
                          );
                        },
                      ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CircularProgressIndicator(),
                ),
              RecordButton(
                isRecording: _isRecording,
                isLoading: _isLoading || _attempts.length >= _maxAttempts,
                onTap: _toggleRecording,
              ),
              const SizedBox(height: 10),
              Text(
                _attempts.length >= _maxAttempts
                    ? '연습 완료! 점수 변화를 확인해보세요.'
                    : _isRecording
                        ? '말한 뒤 버튼을 다시 눌러 분석하세요.'
                        : '최대 3번까지 다시 연습할 수 있어요.',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrillAttempt {
  final String targetWord;
  final String recognizedText;
  // 점수 = STT가 목표 단어를 얼마나 정확히 받아썼나(자모 유사도). 발음 정확도의 정직한 신호.
  // (profile_score는 발음 정확도를 못 재는 게 검증돼서 더 이상 쓰지 않음)
  final double score;

  const _DrillAttempt({
    required this.targetWord,
    required this.recognizedText,
    required this.score,
  });

  factory _DrillAttempt.fromResult(ProcessResult result, String targetWord) {
    final raw = result.stt.text.trim();
    return _DrillAttempt(
      targetWord: targetWord,
      recognizedText: raw.isEmpty ? '(인식 실패)' : raw,
      score: raw.isEmpty ? 0 : recognitionScore(targetWord, raw),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final _DrillAttempt attempt;
  final int index;
  final double? firstScore; // 첫 시도 점수 (개선 추이 표시용)

  const _AttemptCard({
    required this.attempt,
    required this.index,
    this.firstScore,
  });

  List<String> get _feedbacks {
    // 인식 자체가 안 된 경우
    if (attempt.recognizedText == '(인식 실패)') {
      return ['소리가 잘 안 들렸어요. 또박또박 다시 말해볼까요?'];
    }
    // STT 심판: 목표 단어와 인식된 단어를 자모로 비교.
    final confusion =
        diagnoseConfusion(attempt.targetWord, attempt.recognizedText);
    if (confusion != null) {
      return ['${confusion.description} ${confusion.tip}'];
    }
    // 목표대로 인식됨 = 또렷하게 잘 말함
    return ['"${attempt.targetWord}"로 또렷하게 잘 말했어요! 👍'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$index번째 연습',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (firstScore != null) ...[
                Text(
                  scoreDeltaLabel(attempt.score, firstScore!),
                  style: TextStyle(
                    color: scoreDeltaColor(attempt.score, firstScore!),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                scoreBandLabel(attempt.score),
                style: TextStyle(
                  color: scoreBandColor(attempt.score),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('인식: ${attempt.recognizedText}'),
          const SizedBox(height: 8),
          if (_feedbacks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '연습 피드백',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9500),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._feedbacks.map(
                    (feedback) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        feedback,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
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

