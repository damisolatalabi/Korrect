import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/scenario_model.dart';
import '../models/process_result.dart';
import 'audio_service.dart';

class ApiService {
  static Future<List<Scenario>> getScenarios() async {
    final response = await http
        .get(Uri.parse('${AppConstants.baseUrl}/api/scenario'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['scenarios'] as List)
          .map((e) => Scenario.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('시나리오 불러오기 실패 (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> getScenarioDetail(String scenarioId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.baseUrl}/api/scenario/$scenarioId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('시나리오 상세 불러오기 실패');
  }

  static Future<Map<String, dynamic>> getOpeningMessage(String scenarioId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.baseUrl}/api/scenario/$scenarioId/opening'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('시작 메시지 불러오기 실패');
  }

  static Future<ProcessResult> processTurn({
    required String scenarioId,
    required RecordedAudio audio,
    required List<Map<String, String>> history,
    required int turnIndex,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/api/scenario/$scenarioId/process'),
    );

    if (audio.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audio.bytes!,
        filename: audio.filename,
      ));
    } else if (audio.file != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audio.file!.path,
        filename: audio.filename,
      ));
    }
    request.fields['history'] = jsonEncode(history);
    request.fields['turn_index'] = turnIndex.toString();

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return ProcessResult.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception('처리 실패 (${response.statusCode}): ${response.body}');
  }

  /// 발음 드릴 전용: STT + 발음 점수만 (AI 대화·레퍼런스 생략).
  static Future<ProcessResult> analyzeDrill({
    required RecordedAudio audio,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/api/scenario/drill/process'),
    );

    if (audio.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audio.bytes!,
        filename: audio.filename,
      ));
    } else if (audio.file != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audio.file!.path,
        filename: audio.filename,
      ));
    }

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return ProcessResult.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception('드릴 분석 실패 (${response.statusCode}): ${response.body}');
  }
}
