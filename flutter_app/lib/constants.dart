class AppConstants {
  // 서버 주소 - 환경에 맞게 변경
  // static const String baseUrl = 'http://10.0.2.2:8000'; // 안드로이드 에뮬레이터
  // static const String baseUrl = 'http://10.0.2.2:8080'; // 안드로이드 에뮬레이터
  static const String baseUrl = 'http://localhost:8080'; // 웹/iOS 시뮬레이터
  // static const String baseUrl = 'http://49.174.253.201:8080'; // 실제 기기

  // UI 색상
  static const int primaryColor = 0xFF1982C4; // blue
  static const int accentColor =  0xFFFF9500; //orange
  static const int bgColor = 0xFFFFF9E6; // light cream

  // 시나리오별 이모지
  static const Map<String, String> scenarioEmoji = {
    'hospital': '🏥',
    'bank': '🏦',
    'immigration': '🛂',
    'school': '🏫',
    'restaurant': '🍽️',
    'mart': '🛒',
  };
}
