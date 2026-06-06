import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/pronunciation_drills.dart';
import '../services/progress_service.dart';
import 'word_drill_screen.dart';

/// 발음 교정 중심 진입점.
/// (1) 고려인 특화 발음 포인트 드릴, (2) 그동안 어려워한 단어 누적 — 둘 다 반복 드릴로 연결.
class PronunciationPracticeScreen extends StatefulWidget {
  const PronunciationPracticeScreen({super.key});

  @override
  State<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends State<PronunciationPracticeScreen> {
  List<String> _weakWords = [];
  List<MapEntry<String, int>> _weakPhonemes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await ProgressService.loadHistory();
    final weakPhonemes = await ProgressService.loadWeakPhonemes();
    final seen = <String>{};
    final out = <String>[];
    for (final record in history) {
      for (final w in record.wordRecords) {
        final word = w.word.trim();
        if (word.isEmpty) continue;
        if (w.score == null || w.score! >= 70) continue; // 잘한 단어는 제외
        if (seen.add(word)) out.add(word);
      }
    }
    if (!mounted) return;
    setState(() {
      _weakWords = out.take(12).toList();
      _weakPhonemes = weakPhonemes.take(6).toList();
      _loading = false;
    });
  }

  Future<void> _startDrill(String word) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WordDrillScreen(targetWord: word)),
    );
    // 드릴에서 새로 잡힌 약한 음소를 반영해 갱신.
    await _loadData();
  }

  void _startPhonemeDrill(String phoneme) {
    final set = drillSetForPhoneme(phoneme);
    if (set == null || set.words.isEmpty) return;
    _startDrill(set.words.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.bgColor),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColor),
        title: const Text('발음 연습',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '소리를 골라 또박또박 반복 연습해요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '한 단어를 3번까지 따라 말하며 좋아지는지 확인해요.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          if (_weakPhonemes.isNotEmpty) ...[
            const _SectionTitle('내가 약한 소리'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _weakPhonemes)
                  ActionChip(
                    label: Text('${entry.key}  ·  ${entry.value}회'),
                    avatar: const Icon(Icons.graphic_eq, size: 16),
                    backgroundColor: Colors.red.shade50,
                    side: BorderSide(color: Colors.red.shade200),
                    onPressed: () => _startPhonemeDrill(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const _SectionTitle('고려인 발음 포인트'),
          const SizedBox(height: 8),
          ...koryoSaramDrills.map((set) => _DrillSetCard(
                set: set,
                onWordTap: _startDrill,
              )),
          const SizedBox(height: 16),
          const _SectionTitle('내가 어려워한 단어'),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else if (_weakWords.isEmpty)
            Text(
              '아직 없어요. 회화나 위 드릴을 하면 어려웠던 단어가 여기 모여요.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in _weakWords)
                  ActionChip(
                    label: Text(word),
                    avatar: const Icon(Icons.mic_rounded, size: 16),
                    backgroundColor: Colors.white,
                    onPressed: () => _startDrill(word),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    );
  }
}

class _DrillSetCard extends StatelessWidget {
  final DrillSet set;
  final void Function(String word) onWordTap;

  const _DrillSetCard({required this.set, required this.onWordTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(set.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(set.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(set.subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in set.words)
                  ActionChip(
                    label: Text(word),
                    avatar: const Icon(Icons.mic_rounded, size: 16),
                    backgroundColor: const Color(0xFFFFF9E6),
                    side: const BorderSide(color: Color(0xFFFFC107)),
                    onPressed: () => onWordTap(word),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
