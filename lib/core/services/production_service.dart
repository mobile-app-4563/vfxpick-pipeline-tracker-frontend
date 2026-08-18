import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../services/api_controller.dart';

class ProductionService {
  final ApiController _api = ApiController.instance;

  /// Fetch production concerns for a show
  Future<Map<String, dynamic>> getProductionConcerns({
    String showId = '',
    String status = '',
    String priority = '',
  }) async {
    try {
      String queryParams = '?showId=$showId';
      if (status.isNotEmpty) queryParams += '&status=$status';
      if (priority.isNotEmpty) queryParams += '&priority=$priority';

      final response = await _api.get(
        '${ApiConstants.production}/concerns$queryParams',
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to fetch production concerns',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.getProductionConcerns error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch production concerns: $e',
      };
    }
  }

  /// Get a single production concern
  Future<Map<String, dynamic>> getProductionConcern(String productionId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.production}/concerns/$productionId',
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to fetch concern',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.getProductionConcern error: $e');
      return {'success': false, 'error': 'Failed to fetch concern: $e'};
    }
  }

  /// Create a new production concern
  Future<Map<String, dynamic>> createProductionConcern({
    required String showId,
    String? shotId,
    required String concernType,
    String? concernDescription,
    String status = 'Open',
    String priority = 'Medium',
    String? assignedTo,
    String? dueDate,
    String? plannedResolution,
    String? impactArea,
  }) async {
    try {
      final body = {
        'showId': showId,
        'shotId': shotId,
        'concernType': concernType,
        'concernDescription': concernDescription,
        'status': status,
        'priority': priority,
        'assignedTo': assignedTo,
        'dueDate': dueDate,
        'plannedResolution': plannedResolution,
        'impactArea': impactArea,
      };

      final response = await _api.post(
        '${ApiConstants.production}/concerns',
        body,
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to create concern',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.createProductionConcern error: $e');
      return {'success': false, 'error': 'Failed to create concern: $e'};
    }
  }

  /// Update a production concern (editable cells)
  Future<Map<String, dynamic>> updateProductionConcern(
    String productionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _api.put(
        '${ApiConstants.production}/concerns/$productionId',
        updates,
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to update concern',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.updateProductionConcern error: $e');
      return {'success': false, 'error': 'Failed to update concern: $e'};
    }
  }

  /// Delete a production concern
  Future<Map<String, dynamic>> deleteProductionConcern(
    String productionId,
  ) async {
    try {
      final response = await _api.delete(
        '${ApiConstants.production}/concerns/$productionId',
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to delete concern',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.deleteProductionConcern error: $e');
      return {'success': false, 'error': 'Failed to delete concern: $e'};
    }
  }

  /// Bulk create/update production concerns (from Excel)
  Future<Map<String, dynamic>> bulkUpsertConcerns({
    required String showId,
    required List<Map<String, dynamic>> rows,
  }) async {
    try {
      final body = {'showId': showId, 'rows': rows};

      final response = await _api.post(
        '${ApiConstants.production}/concerns/bulk-upsert',
        body,
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to bulk upsert concerns',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.bulkUpsertConcerns error: $e');
      return {'success': false, 'error': 'Failed to bulk upsert concerns: $e'};
    }
  }

  /// Fetch the full production management grid (20 Excel-template columns).
  Future<Map<String, dynamic>> getProductionGrid() async {
    try {
      final response = await _api.get(ApiConstants.productionGrid);

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to fetch production grid',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.getProductionGrid error: $e');
      return {'success': false, 'error': 'Failed to fetch production grid: $e'};
    }
  }

  /// Bulk-sync edited grid cells back to the server.
  ///
  /// [rows] is a list of `{"shotId": "...", "updates": {fieldKey: value}}`.
  Future<Map<String, dynamic>> syncProductionGrid(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final body = {'rows': rows};

      final response = await _api.post(ApiConstants.productionGridSync, body);

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to sync production grid',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.syncProductionGrid error: $e');
      return {'success': false, 'error': 'Failed to sync production grid: $e'};
    }
  }

  /// Manually create a single production-grid row (a shot).
  ///
  /// [row] contains the 16 editable grid fields plus `client` / `show`
  /// (names) and/or `showId`, `shotCode` and `tasks` (department).
  Future<Map<String, dynamic>> createProductionGridRow(
    Map<String, dynamic> row,
  ) async {
    try {
      final response = await _api.post(ApiConstants.productionGrid, row);

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to create grid row',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.createProductionGridRow error: $e');
      return {'success': false, 'error': 'Failed to create grid row: $e'};
    }
  }

  /// Bulk create/update production-grid rows (from Excel/CSV import).
  ///
  /// [rows] is a list of grid-field maps (see [createProductionGridRow]).
  Future<Map<String, dynamic>> bulkUpsertProductionGrid(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final body = {'rows': rows};

      final response = await _api.post(
        ApiConstants.productionGridBulkUpsert,
        body,
      );

      if (response['success'] == true) {
        return response;
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to bulk upsert grid rows',
        };
      }
    } catch (e) {
      debugPrint('ProductionService.bulkUpsertProductionGrid error: $e');
      return {'success': false, 'error': 'Failed to bulk upsert grid rows: $e'};
    }
  }
}
