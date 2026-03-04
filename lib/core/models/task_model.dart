// lib/core/models/task_model.dart

enum TaskType { marketing, customer_interaction, field_work, other }

enum TaskStatus { pending, approved, rejected }

class TaskModel {
  final String id;
  final String employeeId;
  final TaskType taskType;
  final String description;
  final String? notes;
  final List<String> photos;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final TaskStatus status;
  final double? bonusAmount;
  final String? adminNotes;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const TaskModel({
    required this.id,
    required this.employeeId,
    required this.taskType,
    required this.description,
    this.notes,
    required this.photos,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.status,
    this.bonusAmount,
    this.adminNotes,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      employeeId: map['employeeId'] as String,
      taskType: TaskType.values.firstWhere(
        (t) => t.name == (map['taskType'] as String),
        orElse: () => TaskType.other,
      ),
      description: map['description'] as String,
      notes: map['notes'] as String?,
      photos: List<String>.from(map['photos'] as List? ?? []),
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      customerAddress: map['customerAddress'] as String?,
      status: TaskStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String),
        orElse: () => TaskStatus.pending,
      ),
      bonusAmount: (map['bonusAmount'] as num?)?.toDouble(),
      adminNotes: map['adminNotes'] as String?,
      submittedAt: (map['submittedAt'] as dynamic).toDate() as DateTime,
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'taskType': taskType.name,
      'description': description,
      'notes': notes,
      'photos': photos,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'status': status.name,
      'bonusAmount': bonusAmount,
      'adminNotes': adminNotes,
      'submittedAt': submittedAt,
      'reviewedAt': reviewedAt,
    };
  }

  TaskModel copyWith({
    TaskStatus? status,
    double? bonusAmount,
    String? adminNotes,
    DateTime? reviewedAt,
  }) {
    return TaskModel(
      id: id,
      employeeId: employeeId,
      taskType: taskType,
      description: description,
      notes: notes,
      photos: photos,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      status: status ?? this.status,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      adminNotes: adminNotes ?? this.adminNotes,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
