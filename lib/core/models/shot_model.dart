/// Core shot entity shared across Dashboard, Projects and Tasks.
class ShotModel {
  final String shotId;
  final String showId;
  final String? showName;
  final String? clientId;
  final String? clientName;
  final String department;

  /// Multi-department support: parsed list of departments this shot belongs
  /// to (derived from the comma-separated ``department`` value).
  final List<String> departments;
  final String shotCode;
  final int frameIn;
  final int frameOut;
  final int totalFrames;
  final double supervisorBid;
  final double clientBid;
  final DateTime? clientEta;
  final String? notes;
  final String status; // client-facing status
  final String? artistId;
  final String? artistName;
  final double artistBid;
  final DateTime? artistEta;
  final String? description;
  final String? supervisorStatus;
  final String artistStatus;
  final DateTime? allocatedDate;
  final double mandays;
  final DateTime? dueDate;
  final String? clientFeedback;
  // New Excel-header fields
  final String? coordinator;
  final String? levelOfShot;
  final DateTime? allocationDate;
  final DateTime? allocationEta;
  final DateTime? startingDate;
  final DateTime? completeDate;
  final double dailyWip;
  final double consumedMandays;
  final double savedMandays;
  final String? approvedVersion;
  final String? approvedBy;
  final String? comments;
  final String? complexity;
  final String? priority;
  final String? fromRoto;
  final String? fromPaint;
  final String? fromMm;
  final String? fromComp;

  ShotModel({
    required this.shotId,
    required this.showId,
    this.showName,
    this.clientId,
    this.clientName,
    required this.department,
    this.departments = const [],
    required this.shotCode,
    this.frameIn = 0,
    this.frameOut = 0,
    this.totalFrames = 0,
    this.supervisorBid = 0,
    this.clientBid = 0,
    this.clientEta,
    this.notes,
    this.status = 'Awaiting Approval',
    this.artistId,
    this.artistName,
    this.artistBid = 0,
    this.artistEta,
    this.description,
    this.supervisorStatus,
    this.artistStatus = 'YTS',
    this.allocatedDate,
    this.mandays = 0,
    this.dueDate,
    this.clientFeedback,
    this.coordinator,
    this.levelOfShot,
    this.allocationDate,
    this.allocationEta,
    this.startingDate,
    this.completeDate,
    this.dailyWip = 0,
    this.consumedMandays = 0,
    this.savedMandays = 0,
    this.approvedVersion,
    this.approvedBy,
    this.comments,
    this.complexity,
    this.priority,
    this.fromRoto,
    this.fromPaint,
    this.fromMm,
    this.fromComp,
  });

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString());

  static double _double(dynamic v) => v == null
      ? 0.0
      : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  static int _int(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  static List<String> _departmentsOf(Map<String, dynamic> json) {
    final raw = json['departments'];
    if (raw is List) {
      final list = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    // Backward compatibility: parse the comma-separated department string.
    final dept = (json['department'] ?? '').toString();
    return dept
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory ShotModel.fromJson(Map<String, dynamic> json) {
    return ShotModel(
      shotId: json['shotId'] ?? '',
      showId: json['showId'] ?? '',
      showName: json['showName'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      department: json['department'] ?? '',
      departments: _departmentsOf(json),
      shotCode: json['shotCode'] ?? '',
      frameIn: _int(json['frameIn']),
      frameOut: _int(json['frameOut']),
      totalFrames: _int(json['totalFrames']),
      supervisorBid: _double(json['supervisorBid']),
      clientBid: _double(json['clientBid']),
      clientEta: _date(json['clientEta']),
      notes: json['notes'],
      status: json['status'] ?? 'Awaiting Approval',
      artistId: json['artistId'],
      artistName: json['artistName'],
      artistBid: _double(json['artistBid']),
      artistEta: _date(json['artistEta']),
      description: json['description'],
      supervisorStatus: json['supervisorStatus'],
      artistStatus: json['artistStatus'] ?? 'YTS',
      allocatedDate: _date(json['allocatedDate']),
      mandays: _double(json['mandays']),
      dueDate: _date(json['dueDate']),
      clientFeedback: json['clientFeedback'],
      coordinator: json['coordinator'],
      levelOfShot: json['levelOfShot'],
      allocationDate: _date(json['allocationDate']),
      allocationEta: _date(json['allocationEta']),
      startingDate: _date(json['startingDate']),
      completeDate: _date(json['completeDate']),
      dailyWip: _double(json['dailyWip']),
      consumedMandays: _double(json['consumedMandays']),
      savedMandays: _double(json['savedMandays']),
      approvedVersion: json['approvedVersion'],
      approvedBy: json['approvedBy'],
      comments: json['comments'],
      complexity: json['complexity'],
      priority: json['priority'],
      fromRoto: json['fromRoto'],
      fromPaint: json['fromPaint'],
      fromMm: json['fromMm'],
      fromComp: json['fromComp'],
    );
  }
}
