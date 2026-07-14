import 'package:flutter/material.dart';

import '../../../core/models/shot_model.dart';
import '../../../core/services/bidding_service.dart';

/// Bidding controller for managing pending bids workflow.
class BiddingController extends ChangeNotifier {
  final BiddingService _biddingService = BiddingService();

  List<ShotModel> _pendingBids = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedDepartment;
  String? _selectedStatus;

  List<ShotModel> get pendingBids => _pendingBids;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get selectedDepartment => _selectedDepartment;
  String? get selectedStatus => _selectedStatus;

  /// Fetch pending bids with optional filters
  Future<void> fetchPendingBids({String? department, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _pendingBids = [];
    notifyListeners();

    try {
      final response = await _biddingService.getPendingBids(
        department: department,
        status: status,
      );

      final bidsData = (response['pendingBids'] as List<dynamic>?) ?? [];
      _pendingBids = bidsData
          .map((item) => ShotModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _selectedDepartment = department;
      _selectedStatus = status;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load pending bids: $e';
      _pendingBids = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update bids for a specific shot
  Future<void> updateBids(
    String shotId, {
    required double supervisorBid,
    required double clientBid,
    required double artistBid,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _biddingService.updateShotBids(
        shotId,
        supervisorBid: supervisorBid,
        clientBid: clientBid,
        artistBid: artistBid,
      );

      // Update the shot in the list
      final shotData = response['shot'] as Map<String, dynamic>?;
      if (shotData != null) {
        final updatedShot = ShotModel.fromJson(shotData);
        final index = _pendingBids.indexWhere((s) => s.shotId == shotId);
        if (index != -1) {
          _pendingBids[index] = updatedShot;
        }
      }

      _successMessage = 'Bid updated successfully';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update bid: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve a bid
  Future<void> approveBid(String shotId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _biddingService.approveBid(shotId);

      final shotData = response['shot'] as Map<String, dynamic>?;
      if (shotData != null) {
        final updatedShot = ShotModel.fromJson(shotData);
        final index = _pendingBids.indexWhere((s) => s.shotId == shotId);
        if (index != -1) {
          _pendingBids[index] = updatedShot;
        }
      }

      _successMessage = 'Bid approved successfully';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to approve bid: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject a bid
  Future<void> rejectBid(String shotId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _biddingService.rejectBid(shotId);

      final shotData = response['shot'] as Map<String, dynamic>?;
      if (shotData != null) {
        final updatedShot = ShotModel.fromJson(shotData);
        final index = _pendingBids.indexWhere((s) => s.shotId == shotId);
        if (index != -1) {
          _pendingBids[index] = updatedShot;
        }
      }

      _successMessage = 'Bid rejected - shot reverted to Hold status';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to reject bid: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cached data
  void clear() {
    _pendingBids = [];
    _errorMessage = null;
    _successMessage = null;
    _selectedDepartment = null;
    _selectedStatus = null;
    _isLoading = false;
    notifyListeners();
  }
}
