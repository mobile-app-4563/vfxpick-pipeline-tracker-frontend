import 'shot_model.dart';

/// TodaysPickoutModel represents a shot for today with priority ranking.
/// Wraps ShotModel and adds priority-related fields for display and sorting.
class TodaysPickoutModel {
  final ShotModel shot;
  final int priorityRank; // 1 = highest, used for visual indicators
  final String priorityLabel; // e.g., "Critical", "High", "Medium", "Low"
  final String priorityReason; // e.g., "Due today", "Bid pending", "Urgent"

  TodaysPickoutModel({
    required this.shot,
    required this.priorityRank,
    required this.priorityLabel,
    required this.priorityReason,
  });

  /// Factory to create from shot JSON (API response)
  factory TodaysPickoutModel.fromShot(
    Map<String, dynamic> json, {
    required int priorityRank,
    required String priorityLabel,
    required String priorityReason,
  }) {
    return TodaysPickoutModel(
      shot: ShotModel.fromJson(json),
      priorityRank: priorityRank,
      priorityLabel: priorityLabel,
      priorityReason: priorityReason,
    );
  }

  /// Calculate priority based on shot properties
  static TodaysPickoutModel calculatePriority(Map<String, dynamic> json) {
    final shot = ShotModel.fromJson(json);
    final dueDate = shot.dueDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int priorityRank = 4; // Default: Low
    String priorityLabel = 'Low';
    String priorityReason = 'Standard';

    // Priority calculation:
    // 1. Due date urgency (critical if today, high if tomorrow, etc.)
    if (dueDate != null) {
      final daysDue = dueDate.difference(today).inDays;
      if (daysDue == 0) {
        priorityRank = 1;
        priorityLabel = 'Critical';
        priorityReason = 'Due today';
      } else if (daysDue == 1) {
        priorityRank = 2;
        priorityLabel = 'High';
        priorityReason = 'Due tomorrow';
      } else if (daysDue <= 3) {
        priorityRank = 3;
        priorityLabel = 'Medium';
        priorityReason = 'Due in $daysDue days';
      }
    }

    // 2. Override if bid is pending (supervisor_bid = 0)
    if (shot.supervisorBid == 0 && priorityRank > 2) {
      priorityRank = 2;
      priorityLabel = 'High';
      priorityReason = 'Bid pending';
    }

    // 3. Department context (no override, just for information)
    // This is kept for reference but doesn't change rank

    return TodaysPickoutModel(
      shot: shot,
      priorityRank: priorityRank,
      priorityLabel: priorityLabel,
      priorityReason: priorityReason,
    );
  }

  /// Convert to JSON for persistence or API calls
  Map<String, dynamic> toJson() {
    return {
      'shot': shot,
      'priorityRank': priorityRank,
      'priorityLabel': priorityLabel,
      'priorityReason': priorityReason,
    };
  }
}
