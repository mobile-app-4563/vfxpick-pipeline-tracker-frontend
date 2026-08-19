// Supporting domain models for the restructured pipeline.

DateTime? _parseDate(dynamic v) =>
    (v == null || v == '') ? null : DateTime.tryParse(v.toString());

double _toDouble(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

int _toInt(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

class ClientModel {
  final String clientId;
  final String clientName;
  ClientModel({required this.clientId, required this.clientName});
  factory ClientModel.fromJson(Map<String, dynamic> j) => ClientModel(
    clientId: j['clientId'] ?? '',
    clientName: j['clientName'] ?? '',
  );
}

class ShowModel {
  final String showId;
  final String clientId;
  final String showName;
  ShowModel({
    required this.showId,
    required this.clientId,
    required this.showName,
  });
  factory ShowModel.fromJson(Map<String, dynamic> j) => ShowModel(
    showId: j['showId'] ?? '',
    clientId: j['clientId'] ?? '',
    showName: j['showName'] ?? '',
  );
}

/// One row of the dashboard department table (grouped by client + show).
class DashboardRow {
  final String clientId;
  final String clientName;
  final String showId;
  final String showName;
  final int shotCount;
  final DateTime? dueDate;
  final double mandays;
  DashboardRow({
    required this.clientId,
    required this.clientName,
    required this.showId,
    required this.showName,
    required this.shotCount,
    this.dueDate,
    required this.mandays,
  });
  factory DashboardRow.fromJson(Map<String, dynamic> j) => DashboardRow(
    clientId: j['clientId'] ?? '',
    clientName: j['clientName'] ?? '',
    showId: j['showId'] ?? '',
    showName: j['showName'] ?? '',
    shotCount: _toInt(j['shotCount']),
    dueDate: _parseDate(j['dueDate']),
    mandays: _toDouble(j['mandays']),
  );
}

class DashboardDepartment {
  final String department;
  final List<DashboardRow> rows;
  final int targetShows;
  final int targetShotCount;
  DashboardDepartment({
    required this.department,
    required this.rows,
    required this.targetShows,
    required this.targetShotCount,
  });
  factory DashboardDepartment.fromJson(Map<String, dynamic> j) {
    final target = (j['target'] as Map<String, dynamic>?) ?? const {};
    return DashboardDepartment(
      department: j['department'] ?? '',
      rows: ((j['rows'] as List<dynamic>?) ?? const [])
          .map((e) => DashboardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetShows: _toInt(target['shows']),
      targetShotCount: _toInt(target['totalShotCount']),
    );
  }
}

class InventActiveShow {
  final String showId;
  final String showName;
  final String clientId;
  final String clientName;
  final String status;
  final int shotCount;
  final double totalMandays;
  final DateTime? minDueDate;
  final DateTime? maxDueDate;
  final List<String> departments;
  final DateTime? lastUpdatedAt;
  final List<InventActiveShotDetail> shots;

  InventActiveShow({
    required this.showId,
    required this.showName,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.shotCount,
    required this.totalMandays,
    this.minDueDate,
    this.maxDueDate,
    required this.departments,
    this.lastUpdatedAt,
    required this.shots,
  });

  factory InventActiveShow.fromJson(Map<String, dynamic> j) => InventActiveShow(
    showId: j['showId'] ?? '',
    showName: j['showName'] ?? '',
    clientId: j['clientId'] ?? '',
    clientName: j['clientName'] ?? '',
    status: j['status'] ?? '',
    shotCount: _toInt(j['shotCount']),
    totalMandays: _toDouble(j['totalMandays']),
    minDueDate: _parseDate(j['minDueDate']),
    maxDueDate: _parseDate(j['maxDueDate']),
    departments: ((j['departments'] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
    lastUpdatedAt: _parseDate(j['lastUpdatedAt']),
    shots: ((j['shots'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(InventActiveShotDetail.fromJson)
        .toList(growable: false),
  );
}

class InventActiveShotDetail {
  final String shotId;
  final String shotCode;
  final String department;
  final String status;
  final String? artistName;
  final double mandays;
  final DateTime? dueDate;

  InventActiveShotDetail({
    required this.shotId,
    required this.shotCode,
    required this.department,
    required this.status,
    this.artistName,
    required this.mandays,
    this.dueDate,
  });

  factory InventActiveShotDetail.fromJson(Map<String, dynamic> j) =>
      InventActiveShotDetail(
        shotId: j['shotId'] ?? '',
        shotCode: j['shotCode'] ?? '',
        department: j['department'] ?? '',
        status: j['status'] ?? '',
        artistName: j['artistName'],
        mandays: _toDouble(j['mandays']),
        dueDate: _parseDate(j['dueDate']),
      );
}

class TeamMember {
  final String userId;
  final String name;
  final String department;
  final String role;
  final String? level;
  final String avatar;
  TeamMember({
    required this.userId,
    required this.name,
    required this.department,
    required this.role,
    this.level,
    this.avatar = '',
  });
  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    userId: j['userId'] ?? '',
    name: j['name'] ?? '',
    department: j['department'] ?? '',
    role: j['role'] ?? '',
    level: j['level'],
    avatar: j['avatar'] ?? '',
  );
}

class DepartmentTeam {
  final String department;
  final List<TeamMember> members;
  DepartmentTeam({required this.department, required this.members});
  factory DepartmentTeam.fromJson(Map<String, dynamic> j) => DepartmentTeam(
    department: j['department'] ?? '',
    members: ((j['members'] as List<dynamic>?) ?? const [])
        .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DepartmentReview {
  final String department;
  final int month;
  final int year;
  final int totalShows;
  final int totalShots;
  final double totalMandays;
  final List<DepartmentReviewDetail> detailRows;
  DepartmentReview({
    required this.department,
    required this.month,
    required this.year,
    required this.totalShows,
    required this.totalShots,
    required this.totalMandays,
    required this.detailRows,
  });
  factory DepartmentReview.fromJson(Map<String, dynamic> j) => DepartmentReview(
    department: j['department'] ?? '',
    month: _toInt(j['month']),
    year: _toInt(j['year']),
    totalShows: _toInt(j['totalShows']),
    totalShots: _toInt(j['totalShots']),
    totalMandays: _toDouble(j['totalMandays']),
    detailRows: ((j['detailRows'] as List<dynamic>?) ?? const [])
        .map((e) => DepartmentReviewDetail.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class IndividualReview {
  final String userId;
  final String name;
  final String department;
  final int shotsWorked;
  final double mandaysDelivered;
  final List<IndividualReviewDetail> detailRows;
  IndividualReview({
    required this.userId,
    required this.name,
    required this.department,
    required this.shotsWorked,
    required this.mandaysDelivered,
    required this.detailRows,
  });
  factory IndividualReview.fromJson(Map<String, dynamic> j) => IndividualReview(
    userId: j['userId'] ?? '',
    name: j['name'] ?? '',
    department: j['department'] ?? '',
    shotsWorked: _toInt(j['shotsWorked']),
    mandaysDelivered: _toDouble(j['mandaysDelivered']),
    detailRows: ((j['detailRows'] as List<dynamic>?) ?? const [])
        .map((e) => IndividualReviewDetail.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DepartmentReviewDetail {
  final String clientNo;
  final String show;
  final String shot;
  final DateTime? date;
  final double mandays;
  final String artist;
  final String clientFeedback;

  DepartmentReviewDetail({
    required this.clientNo,
    required this.show,
    required this.shot,
    this.date,
    required this.mandays,
    required this.artist,
    required this.clientFeedback,
  });

  factory DepartmentReviewDetail.fromJson(Map<String, dynamic> j) =>
      DepartmentReviewDetail(
        clientNo: j['clientNo'] ?? '',
        show: j['show'] ?? '',
        shot: j['shot'] ?? '',
        date: _parseDate(j['date']),
        mandays: _toDouble(j['mandays']),
        artist: j['artist'] ?? '',
        clientFeedback: j['clientFeedback'] ?? '',
      );
}

class IndividualReviewDetail {
  final String clientNo;
  final String show;
  final String shot;
  final DateTime? date;
  final double mandays;
  final String artistStatus;
  final String clientFeedback;

  IndividualReviewDetail({
    required this.clientNo,
    required this.show,
    required this.shot,
    this.date,
    required this.mandays,
    required this.artistStatus,
    required this.clientFeedback,
  });

  factory IndividualReviewDetail.fromJson(Map<String, dynamic> j) =>
      IndividualReviewDetail(
        clientNo: j['clientNo'] ?? '',
        show: j['show'] ?? '',
        shot: j['shot'] ?? '',
        date: _parseDate(j['date']),
        mandays: _toDouble(j['mandays']),
        artistStatus: j['artistStatus'] ?? '',
        clientFeedback: j['clientFeedback'] ?? '',
      );
}

class ReportItem {
  final String clientNo;
  final String show;
  final String shotId;
  final DateTime? date;
  final double mandays;
  final String? clientFeedback;
  // Chart bucket: 'Completed' | 'In Progress' | 'Remaining'.
  final String progress;
  ReportItem({
    required this.clientNo,
    required this.show,
    required this.shotId,
    this.date,
    required this.mandays,
    this.clientFeedback,
    this.progress = 'Remaining',
  });
  factory ReportItem.fromJson(Map<String, dynamic> j) => ReportItem(
    clientNo: j['clientNo'] ?? '',
    show: j['show'] ?? '',
    shotId: j['shotId'] ?? '',
    date: _parseDate(j['date']),
    mandays: _toDouble(j['mandays']),
    clientFeedback: j['clientFeedback'],
    progress: j['progress'] ?? 'Remaining',
  );
}

class ChatMessage {
  final String messageId;
  final String? shotId;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String message;
  final String? attachmentName;
  final String? attachmentUrl;
  final DateTime? createdAt;
  ChatMessage({
    required this.messageId,
    this.shotId,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.message,
    this.attachmentName,
    this.attachmentUrl,
    this.createdAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    messageId: j['messageId'] ?? '',
    shotId: j['shotId'],
    senderId: j['senderId'],
    senderName: j['senderName'],
    senderAvatar: j['senderAvatar'],
    message: j['message'] ?? '',
    attachmentName: j['attachmentName'],
    attachmentUrl: j['attachmentUrl'],
    createdAt: _parseDate(j['createdAt']),
  );
}

class AttachmentModel {
  final String attachmentId;
  final String? shotId;
  final String? uploaderName;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final DateTime? createdAt;
  AttachmentModel({
    required this.attachmentId,
    this.shotId,
    this.uploaderName,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.createdAt,
  });
  factory AttachmentModel.fromJson(Map<String, dynamic> j) => AttachmentModel(
    attachmentId: j['attachmentId'] ?? '',
    shotId: j['shotId'],
    uploaderName: j['uploaderName'],
    fileName: j['fileName'] ?? '',
    fileUrl: j['fileUrl'] ?? '',
    fileType: j['fileType'],
    createdAt: _parseDate(j['createdAt']),
  );
}
