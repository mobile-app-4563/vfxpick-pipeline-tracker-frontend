import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Chat API calls — per-shot messages with attachment support.
class ChatService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getMessages(String shotId) =>
      _api.get(ApiConstants.chat, queryParams: {'shotId': shotId});

  Future<Map<String, dynamic>> sendMessage({
    required String shotId,
    required String message,
    String? attachmentName,
    String? attachmentUrl,
  }) {
    final body = <String, dynamic>{'shotId': shotId, 'message': message};
    if (attachmentName != null) body['attachmentName'] = attachmentName;
    if (attachmentUrl != null) body['attachmentUrl'] = attachmentUrl;
    return _api.post(ApiConstants.chat, body);
  }
}
