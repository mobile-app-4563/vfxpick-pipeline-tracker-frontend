/// ProductionConcernModel wraps a row from the `production_data` table with
/// the same due-date priority ranking used by [TodaysPickoutModel] for shot
/// pickouts, so production concerns can be shown in the Home pickouts card
/// with identical visual/priority behavior.
class ProductionConcernModel {
  final String productionId;
  final String showId;
  final String? shotId;
  final String? concernType;
  final String? concernDescription;
  final String status;
  final String priority; // Concern's own Low/Medium/High/Critical
  final String? assignedTo;
  final String? reportedBy;
  final DateTime? reportedDate;
  final DateTime? dueDate;
  final DateTime? resolvedDate;
  final String? impactArea;
  final String? department;

  // Priority ranking fields (same scheme as shot pickouts)
  final int priorityRank; // 1 = highest, used for visual indicators
  final String priorityLabel; // e.g., "Critical", "High", "Medium", "Low"
  final String priorityReason; // e.g., "Due today", "Due tomorrow", "Urgent"

  const ProductionConcernModel({
    required this.productionId,
    required this.showId,
    this.shotId,
    this.concernType,
    this.concernDescription,
    this.status = 'Open',
    this.priority = 'Medium',
    this.assignedTo,
    this.reportedBy,
    this.reportedDate,
    this.dueDate,
    this.resolvedDate,
    this.impactArea,
    this.department,
    required this.priorityRank,
    required this.priorityLabel,
    required this.priorityReason,
  });

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString());

  static String _str(dynamic v) => v?.toString() ?? '';

  /// Calculate pickout priority from a production concern row using the same
  /// due-date urgency logic as shot pickouts:
  /// due today -> Critical, due tomorrow -> High, due <= 3 days -> Medium.
  /// Falls back to the concern's own priority field when there is no due date.
  static ProductionConcernModel calculatePriority(Map<String, dynamic> json) {
    final dueDate = _date(json['dueDate']);
    final ownPriority = _str(json['priority']).toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int priorityRank = 4; // Default: Low
    String priorityLabel = 'Low';
    String priorityReason = 'Standard';

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
    } else {
      // No due date: rank from the concern's own priority field.
      if (ownPriority == 'critical') {
        priorityRank = 1;
        priorityLabel = 'Critical';
      } else if (ownPriority == 'high') {
        priorityRank = 2;
        priorityLabel = 'High';
      } else if (ownPriority == 'medium') {
        priorityRank = 3;
        priorityLabel = 'Medium';
      } else {
        priorityRank = 4;
        priorityLabel = 'Low';
      }
      priorityReason = 'No due date';
    }

    return ProductionConcernModel(
      productionId: _str(json['productionId']),
      showId: _str(json['showId']),
      shotId: json['shotId']?.toString(),
      concernType: json['concernType']?.toString(),
      concernDescription: json['concernDescription']?.toString(),
      status: _str(json['status']).isEmpty ? 'Open' : _str(json['status']),
      priority: _str(json['priority']).isEmpty
          ? 'Medium'
          : _str(json['priority']),
      assignedTo: json['assignedTo']?.toString(),
      reportedBy: json['reportedBy']?.toString(),
      reportedDate: _date(json['reportedDate']),
      dueDate: dueDate,
      resolvedDate: _date(json['resolvedDate']),
      impactArea: json['impactArea']?.toString(),
      department: json['department']?.toString(),
      priorityRank: priorityRank,
      priorityLabel: priorityLabel,
      priorityReason: priorityReason,
    );
  }
}
