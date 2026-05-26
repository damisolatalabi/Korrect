import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/progress_service.dart';
import '../utils/pronunciation_guidance.dart';
import '../utils/score_band.dart';
import 'word_drill_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<SessionRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await ProgressService.loadHistory();
    setState(() {
      _history = history.reversed.toList(); // 최신순
      _isLoading = false;
    });
  }

  Map<String, List<SessionRecord>> get _grouped {
    final map = <String, List<SessionRecord>>{};
    for (final r in _history) {
      map.putIfAbsent(r.scenarioId, () => []).add(r);
    }
    return map;
  }

  double? _avg(List<SessionRecord> records) {
    final scores = records
        .where((r) => r.totalScore != null)
        .map((r) => r.totalScore!)
        .toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  List<MapEntry<String, int>> get _weakPoints {
    final counts = <String, int>{};
    for (final record in _history) {
      for (final word in record.wordRecords) {
        if (word.score != null && word.score! >= 75) continue;
        final title = tipsForWord(word.word).first.title;
        counts[title] = (counts[title] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.bgColor),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColor),
        title: const Text('내 학습 기록',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const _EmptyView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(history: _history),
                    const SizedBox(height: 16),
                    if (_weakPoints.isNotEmpty) ...[
                      _WeakPronunciationCard(points: _weakPoints),
                      const SizedBox(height: 16),
                    ],
                    ..._grouped.entries.map((e) => _ScenarioSection(
                          scenarioId: e.key,
                          records: e.value,
                          avgScore: _avg(e.value),
                        )),
                  ],
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<SessionRecord> history;

  const _SummaryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final totalSessions = history.length;
    final scores = history
        .where((r) => r.totalScore != null)
        .map((r) => r.totalScore!)
        .toList();
    final avgScore =
        scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: '총 연습', value: '$totalSessions회'),
          Container(width: 1, height: 40, color: Colors.white30),
          _SummaryItem(
            label: '평균 수준',
            value: scoreBandLabel(avgScore),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          _SummaryItem(
            label: '연습한 상황',
            value: '${history.map((r) => r.scenarioId).toSet().length}개',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _WeakPronunciationCard extends StatelessWidget {
  final List<MapEntry<String, int>> points;

  const _WeakPronunciationCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 약한 발음',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18,
                    color: Color(0xFFFF9500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(point.key)),
                  Text(
                    '${point.value}회',
                    style: const TextStyle(
                      color: Color(0xFFFF9500),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioSection extends StatelessWidget {
  final String scenarioId;
  final List<SessionRecord> records;
  final double? avgScore;

  const _ScenarioSection({
    required this.scenarioId,
    required this.records,
    required this.avgScore,
  });

  String get _emoji =>
      AppConstants.scenarioEmoji[scenarioId] ?? '💬';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(records.first.scenarioTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (avgScore != null)
              Text('평균 ${scoreBandLabel(avgScore)}',
                  style: TextStyle(
                      color: scoreBandColor(avgScore),
                      fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        // records는 최신순. 각 기록에 직전(더 오래된) 기록 점수를 넘겨 추이를 표시.
        ...List.generate(records.length, (i) {
          final prev = i + 1 < records.length ? records[i + 1].totalScore : null;
          return _SessionTile(record: records[i], previousScore: prev);
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionRecord record;
  final double? previousScore;

  const _SessionTile({required this.record, this.previousScore});

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _HistoryDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetailSheet(context), 
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(record.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text('${record.turnCount}번 대화',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (record.totalScore != null && previousScore != null) ...[
              Text(
                scoreDeltaLabel(record.totalScore!, previousScore!),
                style: TextStyle(
                  color: scoreDeltaColor(record.totalScore!, previousScore!),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (record.totalScore != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreBandColor(record.totalScore),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  scoreBandLabel(record.totalScore),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              )
            else
              const Text('-', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📚', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('아직 연습 기록이 없어요!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('시나리오를 골라서 연습해봐요 😊',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  final SessionRecord record;

  const _HistoryDetailSheet({required this.record});

  double? get _pronunciationScore {
    final values = [record.mfccScore, record.voiceScore].whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<MapEntry<String, double>> get _majorScoreItems => [
        if (record.profileScore != null) MapEntry('한국어 근접도', record.profileScore!),
        if (record.intonationScore != null) MapEntry('억양', record.intonationScore!),
        if (record.rhythmScore != null) MapEntry('리듬', record.rhythmScore!),
        if (_pronunciationScore != null) MapEntry('발음', _pronunciationScore!),
      ];

  @override
  Widget build(BuildContext context) {
    final practiceGuides = buildPracticeGuides(record.wordRecords);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: ListView(
              controller: scrollController,
              children: [
            // 드래그 핸들바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${record.scenarioTitle} 연습 기록',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              '종합 수준',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              scoreBandLabel(record.totalScore),
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: scoreBandColor(record.totalScore),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '대화 횟수: ${record.turnCount}번',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // 세부 점수 표시aa
            if (_majorScoreItems.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '주요 지표',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._majorScoreItems.map(
                (entry) => _ResultScoreBar(label: entry.key, score: entry.value),
              ),
            ],
            if (record.turnRecords.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '턴별 연습 기록',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...record.turnRecords.map((turn) => _TurnRecordCard(turn: turn)),
            ],
            if (record.wordRecords.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '단어 학습 기록',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in record.wordRecords) _WordChip(record: word),
                ],
              ),
            ],
            if (practiceGuides.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              _PracticeGuideSection(
                guides: practiceGuides,
              ),
            ],
            const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WordChip extends StatelessWidget {
  final WordRecord record;

  const _WordChip({required this.record});

  Color get _backgroundColor {
    final score = record.score;
    if (score == null || score <= 0) return Colors.grey.shade100;
    if (score >= 70) return Colors.green.shade50;
    if (score >= 40) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  Color get _textColor {
    final score = record.score;
    if (score == null || score <= 0) return Colors.black54;
    if (score >= 70) return Colors.green.shade700;
    if (score >= 40) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final score = record.score;
    // 숫자 대신 색으로 수준을 표시(연두/주황/빨강). 인식이 불안정한 경우만 글자로 표시.
    final scoreText = (score != null && score <= 0) ? ' (인식 불안정)' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _textColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${record.word}$scoreText',
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TurnRecordCard extends StatelessWidget {
  final TurnRecord turn;

  const _TurnRecordCard({required this.turn});

  double? get _pronunciationScore {
    final values = [turn.vowelScore, turn.voiceScore].whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<MapEntry<String, double>> get _items => [
        if (turn.profileScore != null) MapEntry('한국어', turn.profileScore!),
        if (turn.intonationScore != null) MapEntry('억양', turn.intonationScore!),
        if (turn.rhythmScore != null) MapEntry('리듬', turn.rhythmScore!),
        if (_pronunciationScore != null) MapEntry('발음', _pronunciationScore!),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${turn.turnNumber}번째 발화',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                scoreBandLabel(turn.totalScore),
                style: TextStyle(
                  color: scoreBandColor(turn.totalScore),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (turn.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              turn.text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final item in _items)
                  Chip(
                    label: Text('${item.key} ${scoreBandLabel(item.value)}'),
                    labelStyle: TextStyle(
                      color: scoreBandColor(item.value),
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: scoreBandColor(item.value).withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ],
          if (turn.wordRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final word in turn.wordRecords) _WordChip(record: word),
              ],
            ),
          ],
        ],
      ),
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
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '교정 가이드',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
            width: 56,
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
              style: TextStyle(
                fontSize: 12,
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
