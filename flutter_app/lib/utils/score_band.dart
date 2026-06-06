import 'package:flutter/material.dart';

/// 점수는 사람 평가와 비교 검증된 '절대 점수'가 아니다.
/// 그래서 사용자에게는 정밀한 숫자(66점) 대신 구간(좋음/보통/연습 필요)으로 보여주고,
/// 숫자는 오직 '이전 대비 변화(추이)'를 나타낼 때만 사용한다.

String scoreBandLabel(double? score) {
  if (score == null) return '-';
  if (score >= 80) return '좋음';
  if (score >= 60) return '보통';
  return '연습 필요';
}

Color scoreBandColor(double? score) {
  if (score == null) return Colors.grey;
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  return Colors.redAccent;
}

/// 점수 구간과 '일치하는' 격려 문구. (배지는 "연습 필요"인데 칭찬은 "정말 좋아요"가
/// 나오는 모순을 막기 위해, 화면 문구를 항상 점수에서 파생시킨다.)
String? scoreEncouragement(double? score) {
  if (score == null) return null;
  if (score >= 80) return '발음이 자연스러워요! 잘하고 있어요 🎉';
  if (score >= 60) return '좋아요! 조금만 더 또박또박 말해볼까요?';
  return '괜찮아요. 천천히 한 번 더 말해볼까요? 💪';
}

/// 절대점수가 아니라 '개선 추이'이므로 변화량은 숫자로 보여줘도 안전하다.
/// 차이가 미미하면(±3 이내) 변화 없음으로 처리해 잡음에 흔들리지 않게 한다.
String scoreDeltaLabel(double current, double previous) {
  final d = (current - previous).round();
  if (d >= 3) return '▲ +$d';
  if (d <= -3) return '▼ $d';
  return '— 비슷';
}

Color scoreDeltaColor(double current, double previous) {
  final d = current - previous;
  if (d >= 3) return Colors.green;
  if (d <= -3) return Colors.redAccent;
  return Colors.grey;
}
