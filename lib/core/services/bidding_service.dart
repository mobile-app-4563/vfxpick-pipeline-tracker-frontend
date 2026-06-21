import 'api_controller.dart';

/// Bidding service for managing supervisor, client, and artist bids.
class BiddingService {
  final ApiController _api = ApiController.instance;

  /// Fetch all pending bids (supervisor_bid=0 or client_bid=0)
  /// Optional query params:
  /// - department: Filter by department
  /// - status: Filter by shot status
  Future<Map<String, dynamic>> getPendingBids({
    String? department,
    String? status,
  }) => _api.get(
    '/bidding/pending',
    queryParams: {
      if (department != null) 'department': department,
      if (status != null) 'status': status,
    },
  );

  /// Get bidding details for a specific shot
  Future<Map<String, dynamic>> getShotBids(String shotId) =>
      _api.get('/bidding/shot/$shotId');

  /// Update bids for a shot
  /// Request body can contain:
  /// - supervisorBid: double
  /// - clientBid: double
  /// - artistBid: double
  Future<Map<String, dynamic>> updateShotBids(
    String shotId, {
    required double supervisorBid,
    required double clientBid,
    required double artistBid,
  }) => _api.put('/bidding/shot/$shotId', {
    'supervisorBid': supervisorBid,
    'clientBid': clientBid,
    'artistBid': artistBid,
  });

  /// Approve a bid (mark shot as Approved)
  Future<Map<String, dynamic>> approveBid(String shotId) =>
      _api.patch('/bidding/shot/$shotId/approve');

  /// Reject a bid (revert shot to Hold status)
  Future<Map<String, dynamic>> rejectBid(String shotId) =>
      _api.patch('/bidding/shot/$shotId/reject');
}
