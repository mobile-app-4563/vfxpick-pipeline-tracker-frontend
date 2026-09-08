import '../../../core/models/production_concern_model.dart';
import '../../../core/models/todays_pickout_model.dart';

/// A single row in the Home "Today's Pickouts" card.
///
/// One [HomePickoutItem] may carry a Project pickout (a shot from the shots
/// table), a Production pickout (a row from the production grid / concern),
/// or both when the same shot exists in both modules. Merging at this level
/// lets the card show one row per shot with the data from both APIs.
class HomePickoutItem {
  TodaysPickoutModel? shot;
  ProductionConcernModel? concern;

  bool get hasProject => shot != null;
  bool get hasProduction => concern != null;

  /// The calendar day this pickout is due (year deliberately ignored by the
  /// UI when bucketing into Due Today / Due Tomorrow).
  DateTime? get dueDate {
    if (shot != null) {
      return shot!.shot.dueDate ??
          shot!.shot.clientEta ??
          shot!.shot.allocatedDate;
    }
    return concern?.dueDate;
  }

  int get priorityRank {
    var min = 4;
    if (shot != null && shot!.priorityRank < min) min = shot!.priorityRank;
    if (concern != null && concern!.priorityRank < min) {
      min = concern!.priorityRank;
    }
    return min;
  }

  String get priorityLabel =>
      shot?.priorityLabel ?? concern?.priorityLabel ?? 'Low';
  String get priorityReason =>
      shot?.priorityReason ?? concern?.priorityReason ?? 'Standard';

  String get shotCode => (shot != null && shot!.shot.shotCode.isNotEmpty)
      ? shot!.shot.shotCode
      : (concern?.shotId ?? '');

  String get showName => shot?.shot.showName ?? concern?.showId ?? '';
  String? get department => shot?.shot.department;
  String? get task => concern?.concernType;
  String? get status => concern?.status;
  String? get notes => concern?.concernDescription;
}
