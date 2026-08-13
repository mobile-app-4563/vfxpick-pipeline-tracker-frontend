import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Assets API calls — supporting materials / shared documents per shot.
class AssetService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getAssets({String? shotId}) => _api.get(
    ApiConstants.assets,
    queryParams: shotId != null ? {'shotId': shotId} : null,
  );

  Future<Map<String, dynamic>> addAsset(Map<String, dynamic> body) =>
      _api.post(ApiConstants.assets, body);

  Future<Map<String, dynamic>> deleteAsset(String attachmentId) =>
      _api.delete(ApiConstants.assetById(attachmentId));
}
