import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGPTService {
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  /// 환경 변수에서 API 키를 가져옵니다.
  static String? get _apiKey {
    return dotenv.env['OPENAI_API_KEY'];
  }

  /// ChatGPT API를 호출하여 단어 정보를 가져옵니다.
  /// 
  /// [word] - 조회할 단어
  /// Returns - 사용자 요청 형식에 맞춘 JSON 문자열
  static Future<Map<String, dynamic>?> getWordInfo(String word) async {
    final apiKey = _apiKey;
    
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      throw Exception(
        'OpenAI API 키가 설정되지 않았습니다.\n\n'
        '설정 방법:\n'
        '1. 프로젝트 루트에 .env 파일 생성 (이미 있다면 다음 단계로)\n'
        '2. .env 파일에 다음 내용 추가:\n'
        '   OPENAI_API_KEY=sk-your-actual-api-key\n'
        '3. API 키 발급: https://platform.openai.com/api-keys\n'
        '4. 앱 재시작'
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final prompt = '''
다음 영어 단어에 대한 정보를 아래 형식의 JSON으로 제공해주세요.

단어: "$word"

응답 형식 (정확히 이 형식을 따르세요):
{
  "word": "$word",
  "pos": ["noun", "verb"],
  "meanings": [
    {
      "id": "${word.toLowerCase()}_1",
      "definition": "[명사] 한국어 정의",
      "examples": [
        "English example sentence. (한국어 번역)"
      ],
      "keywords": ["keyword1", "keyword2"],
      "embedding": {},
      "difficulty": 3,
      "frequency": 0.65
    }
  ],
  "updatedAt": "$now"
}

주의사항:
1. JSON 형식만 반환하세요. 다른 설명이나 마크다운 코드 블록 없이 순수 JSON만 반환하세요.
2. word는 정확히 "$word"로 반환하세요.
3. pos는 영어 품사 배열입니다 (예: ["noun"], ["verb", "noun"]).
4. meanings 배열에 각 의미를 포함하세요. 의미가 여러 개면 여러 개를 추가하세요.
5. 각 meaning의 id는 "${word.toLowerCase()}_1", "${word.toLowerCase()}_2" 형식입니다.
6. definition은 "[품사] 한국어 정의" 형식입니다 (예: "[명사] 확신, 자신감").
7. examples는 영문 예문과 한국어 번역을 포함한 문자열 배열입니다 (예: "She spoke with assurance. (그녀는 자신 있게 말했다.)").
8. keywords는 관련 단어 배열입니다 (영어로).
9. embedding은 항상 빈 객체 {}입니다.
10. difficulty는 1-5 사이의 정수입니다.
11. frequency는 0-1 사이의 실수입니다.
12. updatedAt은 "$now" 형식의 ISO 8601 문자열입니다.
''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant that provides word definitions in JSON format. Always respond with valid JSON only, no additional text.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices'][0]['message']['content'] as String;
        
        // JSON 파싱
        final wordData = jsonDecode(content) as Map<String, dynamic>;
        
        // 응답 형식이 사용자가 요청한 형식과 약간 다를 수 있으므로 정규화
        return _normalizeWordData(wordData, word);
      } else {
        throw Exception('ChatGPT API 호출 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('ChatGPT API 오류: $e');
      rethrow;
    }
  }

  /// API 응답 데이터를 사용자가 요청한 형식으로 정규화합니다.
  static Map<String, dynamic> _normalizeWordData(
    Map<String, dynamic> data,
    String originalWord,
  ) {
    final word = data['word'] as String? ?? originalWord;
    final pos = data['pos'] as List<dynamic>? ?? [];
    final meanings = data['meanings'] as List<dynamic>? ?? [];
    final updatedAt = data['updatedAt'] as String? ?? DateTime.now().toIso8601String();

    // meanings 배열 정규화
    final normalizedMeanings = meanings.map((meaning) {
      if (meaning is! Map<String, dynamic>) {
        return meaning;
      }
      
      final id = meaning['id'] as String? ?? '${word}_${meanings.indexOf(meaning) + 1}';
      final definition = meaning['definition'] as String? ?? '';
      final examples = meaning['examples'] as List<dynamic>? ?? [];
      final keywords = meaning['keywords'] as List<dynamic>? ?? [];
      final embedding = meaning['embedding'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final difficulty = meaning['difficulty'] as int? ?? 3;
      final frequency = meaning['frequency'] as double? ?? 0.5;

      return {
        'id': id,
        'definition': definition,
        'examples': examples.map((e) => e.toString()).toList(),
        'keywords': keywords.map((k) => k.toString()).toList(),
        'embedding': embedding,
        'difficulty': difficulty,
        'frequency': frequency,
      };
    }).toList();

    return {
      'word': word,
      'pos': pos.map((p) => p.toString()).toList(),
      'meanings': normalizedMeanings,
      'updatedAt': updatedAt,
    };
  }
}

