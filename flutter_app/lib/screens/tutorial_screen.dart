import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class TutorialScreen extends StatefulWidget {
  /// 첫 실행이면 종료 시 HomeScreen으로 교체, 그 외엔 단순 pop.
  final bool isFirstLaunch;

  const TutorialScreen({super.key, this.isFirstLaunch = true});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _doneKey = 'korrect_tutorial_done';

  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = <_TutorialPageData>[
    _TutorialPageData(
      emoji: '👋',
      title: '안녕!',
      subtitle: '한국어 발음 친구 Korrect예요',
      description: '재미있게 한국어를 연습해봐요!',
      color: Color(0xFF4CAF50),
    ),
    _TutorialPageData(
      emoji: '🏥',
      title: '여러 상황에서 연습',
      subtitle: '병원·은행·학교·식당·마트',
      description: '어디서든 한국어로 대화해봐요!',
      color: Color(0xFFFF9800),
    ),
    _TutorialPageData(
      emoji: '🎤',
      title: '말해봐요',
      subtitle: '마이크 버튼을 누르고\n한국어로 답해봐요',
      description: 'AI가 다음에 할 말도 친절히 알려줘요',
      color: Color(0xFF2196F3),
    ),
    _TutorialPageData(
      emoji: '🏆',
      title: '점수 받기',
      subtitle: '내 발음을 점수로 알려줘요',
      description: '원어민 발음과 그래프로 비교해봐요!',
      color: Color(0xFFE91E63),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    if (!mounted) return;
    if (widget.isFirstLaunch) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final color = _pages[_currentPage].color;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 건너뛰기 버튼
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  height: 40,
                  child: isLast
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _finish,
                          child: Text(
                            '건너뛰기',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ),
                ),
              ),
            ),
            // 페이지 캐러셀
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _TutorialPage(data: _pages[i]),
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage ? color : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // 다음 / 시작하기 버튼
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLast ? '시작하기!' : '다음',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPageData {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;

  const _TutorialPageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
  });
}

class _TutorialPage extends StatelessWidget {
  final _TutorialPageData data;

  const _TutorialPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(data.emoji, style: const TextStyle(fontSize: 88)),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: data.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
