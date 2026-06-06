import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/ref_player.dart';

class PitchChart extends StatefulWidget {
  final List<double> userPitch;
  final List<double> refPitch;
  final String? refAudioUrl;

  const PitchChart({
    super.key,
    required this.userPitch,
    required this.refPitch,
    this.refAudioUrl,
  });

  @override
  State<PitchChart> createState() => _PitchChartState();
}

class _PitchChartState extends State<PitchChart> {
  RefPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  double get _progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> _toggleKaraoke() async {
    final url = widget.refAudioUrl;
    if (url == null) return;

    if (_isPlaying) {
      await _player?.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
          _position = Duration.zero;
        });
      }
      return;
    }

    // 클릭 즉시 UI 반영 (재생 시작 전 딜레이 가리기)
    setState(() {
      _isPlaying = true;
      _isLoading = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    _player ??= RefPlayer();

    _posSub?.cancel();
    _posSub = _player!.positionStream.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
          _isLoading = false;
        });
      }
    });

    _durSub?.cancel();
    _durSub = _player!.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _completeSub?.cancel();
    _completeSub = _player!.onComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
          _position = Duration.zero;
        });
      }
    });

    try {
      await _player!.play(url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 오류: $e')),
        );
      }
    }
  }

  List<FlSpot> _toSpots(List<double> pitchList) {
    if (pitchList.isEmpty) return [];
    final voiced = <FlSpot>[];
    final total = pitchList.length;
    final step = total > 100 ? total ~/ 100 : 1;
    for (int i = 0; i < total; i += step) {
      if (pitchList[i] > 0) {
        final x = i / (total - 1) * 100;
        voiced.add(FlSpot(x, pitchList[i]));
      }
    }
    return voiced;
  }

  /// Y축 범위 — 절대 Hz 차이가 작아 보이도록 데이터 범위에 큰 패딩 적용.
  ({double minY, double maxY}) _yRange(List<FlSpot> a, List<FlSpot> b) {
    final all = [...a, ...b].map((s) => s.y).toList();
    if (all.isEmpty) return (minY: 50, maxY: 400);
    all.sort();
    final dataMin = all.first;
    final dataMax = all.last;
    final range = (dataMax - dataMin).clamp(40.0, double.infinity);
    final padding = range * 1.2;
    final minY = (dataMin - padding).clamp(0.0, double.infinity);
    final maxY = dataMax + padding;
    return (minY: minY, maxY: maxY);
  }

  @override
  Widget build(BuildContext context) {
    final userSpots = _toSpots(widget.userPitch);
    final refSpots = _toSpots(widget.refPitch);

    if (userSpots.isEmpty) {
      return const Center(child: Text('피치 데이터가 없어요'));
    }

    final canKaraoke = widget.refAudioUrl != null && refSpots.isNotEmpty;
    final progressX = _progress * 100;
    final refTraced = (_isPlaying && refSpots.isNotEmpty)
        ? refSpots.where((s) => s.x <= progressX).toList()
        : <FlSpot>[];
    final userTraced = (_isPlaying && userSpots.isNotEmpty)
        ? userSpots.where((s) => s.x <= progressX).toList()
        : <FlSpot>[];

    final yRange = _yRange(userSpots, refSpots);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LegendItem(color: Colors.blue, label: '내 목소리'),
            const SizedBox(width: 16),
            if (refSpots.isNotEmpty)
              const _LegendItem(color: Colors.orange, label: '원어민'),
            const Spacer(),
            if (canKaraoke)
              TextButton.icon(
                onPressed: _toggleKaraoke,
                icon: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        size: 18,
                        color: Colors.deepPurple,
                      ),
                label: Text(
                  _isPlaying ? '멈추기' : '따라가기',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 100,
              minY: yRange.minY,
              maxY: yRange.maxY,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}Hz',
                      style: const TextStyle(fontSize: 9),
                    ),
                    reservedSize: 40,
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // 사용자 — 재생 중엔 옅게, 정지 시엔 정상
                LineChartBarData(
                  spots: userSpots,
                  isCurved: true,
                  color: _isPlaying
                      ? Colors.blue.withValues(alpha: 0.25)
                      : Colors.blue,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                // 사용자 트레이스 (재생 중에만)
                if (userTraced.isNotEmpty)
                  LineChartBarData(
                    spots: userTraced,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                // 원어민 — 재생 중엔 옅은 배경 트랙, 정지 시엔 점선
                if (refSpots.isNotEmpty)
                  LineChartBarData(
                    spots: refSpots,
                    isCurved: true,
                    color: _isPlaying
                        ? Colors.orange.withValues(alpha: 0.25)
                        : Colors.orange,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    dashArray: _isPlaying ? null : [5, 3],
                  ),
                // 원어민 트레이스 (재생 중에만 진하게 그려짐)
                if (refTraced.isNotEmpty)
                  LineChartBarData(
                    spots: refTraced,
                    isCurved: true,
                    color: Colors.deepOrange,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        if (canKaraoke && _isPlaying)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(
                  _formatTime(_position),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 3,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Colors.deepOrange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_duration),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTime(Duration d) {
    final s = d.inSeconds;
    final ms = (d.inMilliseconds % 1000) ~/ 100;
    return '$s.${ms}s';
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
