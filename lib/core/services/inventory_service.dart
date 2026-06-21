import '../constants/api_constants.dart';
import 'api_controller.dart';

/// Inventory API calls — tracking hardware, software licenses, and hardware assets.
class InventoryService {
  final ApiController _api = ApiController.instance;

  Future<Map<String, dynamic>> getInventoryItems() => _api.get(
    ApiConstants.inventory,
  );

  Future<Map<String, dynamic>> getAssignableUsers() => _api.get(
    '${ApiConstants.inventory}/users',
  );

  Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> body) =>
      _api.post(ApiConstants.inventory, body);

  Future<Map<String, dynamic>> updateInventoryItem(int itemId, Map<String, dynamic> body) =>
      _api.put(ApiConstants.inventoryItem(itemId), body);

  Future<Map<String, dynamic>> deleteInventoryItem(int itemId) =>
      _api.delete(ApiConstants.inventoryItem(itemId));
}
