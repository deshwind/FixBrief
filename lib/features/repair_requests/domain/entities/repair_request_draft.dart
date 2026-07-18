import 'package:flutter/foundation.dart';

enum RepairDraftStatus { draft, submitted }

enum RepairUrgency {
  emergency('emergency', 'Emergency'),
  asap('asap', 'As soon as possible'),
  within24Hours('within_24_hours', 'Within 24 hours'),
  within3Days('within_3_days', 'Within 3 days'),
  within1Week('within_1_week', 'Within 1 week'),
  flexible('flexible', 'Flexible');

  const RepairUrgency(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

enum SymptomKind {
  seen('seen', 'See'),
  heard('heard', 'Hear'),
  felt('felt', 'Feel'),
  smell('smell', 'Smell'),
  heat('heat', 'Heat'),
  vibration('vibration', 'Vibration'),
  movement('movement', 'Movement'),
  warningLight('warning_light', 'Warning light'),
  errorCode('error_code', 'Error code'),
  timing('timing', 'Timing'),
  repairHistory('repair_history', 'Repair history'),
  other('other', 'Other');

  const SymptomKind(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

enum SymptomSource {
  typed('typed'),
  voice('voice'),
  suggested('suggested');

  const SymptomSource(this.databaseValue);
  final String databaseValue;
}

enum RepairEvidenceKind {
  image('image', 'Photo'),
  video('video', 'Video'),
  audio('audio', 'Audio'),
  errorCode('error_code', 'Error code'),
  receipt('receipt', 'Receipt'),
  warranty('warranty', 'Warranty'),
  document('document', 'Document');

  const RepairEvidenceKind(this.databaseValue, this.label);
  final String databaseValue;
  final String label;
}

enum EvidenceUploadStatus { local, pending, uploading, ready, failed }

@immutable
class RepairSymptom {
  const RepairSymptom({
    required this.id,
    required this.kind,
    required this.description,
    this.source = SymptomSource.typed,
  });

  factory RepairSymptom.fromJson(Map<String, Object?> json) {
    return RepairSymptom(
      id: json['id']! as String,
      kind: SymptomKind.values.firstWhere(
        (value) => value.databaseValue == json['kind'],
        orElse: () => SymptomKind.other,
      ),
      description: json['description'] as String? ?? '',
      source: SymptomSource.values.firstWhere(
        (value) => value.databaseValue == json['source'],
        orElse: () => SymptomSource.typed,
      ),
    );
  }

  final String id;
  final SymptomKind kind;
  final String description;
  final SymptomSource source;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.databaseValue,
    'description': description,
    'source': source.databaseValue,
  };
}

@immutable
class RepairEvidence {
  const RepairEvidence({
    required this.id,
    required this.kind,
    required this.localPath,
    required this.filename,
    required this.mimeType,
    required this.byteSize,
    required this.sortOrder,
    this.uploadStatus = EvidenceUploadStatus.local,
    this.failureReason,
  });

  factory RepairEvidence.fromJson(Map<String, Object?> json) {
    return RepairEvidence(
      id: json['id']! as String,
      kind: RepairEvidenceKind.values.firstWhere(
        (value) => value.databaseValue == json['kind'],
        orElse: () => RepairEvidenceKind.document,
      ),
      localPath: json['localPath'] as String? ?? '',
      filename: json['filename'] as String? ?? 'evidence',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      uploadStatus: EvidenceUploadStatus.values.firstWhere(
        (value) => value.name == json['uploadStatus'],
        orElse: () => EvidenceUploadStatus.local,
      ),
      failureReason: json['failureReason'] as String?,
    );
  }

  final String id;
  final RepairEvidenceKind kind;
  final String localPath;
  final String filename;
  final String mimeType;
  final int byteSize;
  final int sortOrder;
  final EvidenceUploadStatus uploadStatus;
  final String? failureReason;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => kind == RepairEvidenceKind.video;
  bool get isAudio => kind == RepairEvidenceKind.audio;

  RepairEvidence copyWith({
    int? sortOrder,
    EvidenceUploadStatus? uploadStatus,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return RepairEvidence(
      id: id,
      kind: kind,
      localPath: localPath,
      filename: filename,
      mimeType: mimeType,
      byteSize: byteSize,
      sortOrder: sortOrder ?? this.sortOrder,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.databaseValue,
    'localPath': localPath,
    'filename': filename,
    'mimeType': mimeType,
    'byteSize': byteSize,
    'sortOrder': sortOrder,
    'uploadStatus': uploadStatus.name,
    'failureReason': failureReason,
  };
}

@immutable
class RepairRequestDraft {
  const RepairRequestDraft({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.currentStep = 0,
    this.status = RepairDraftStatus.draft,
    this.categorySlug,
    this.categoryLabel,
    this.subcategory,
    this.customCategory,
    this.itemName = '',
    this.brand = '',
    this.model = '',
    this.approximateAgeYears,
    this.serialNumber = '',
    this.purchaseDate,
    this.warrantyStatus = '',
    this.previousRepairs = '',
    this.itemLocation = '',
    this.vehicleRegistration = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleYear,
    this.vehicleMileage,
    this.vehicleFuelType = '',
    this.vehicleTransmission = '',
    this.problemDescription = '',
    this.problemStarted = '',
    this.problemOccurrence = '',
    this.isWorsening = false,
    this.isStillUsable = true,
    this.immediatePriorEvent = '',
    this.symptoms = const <RepairSymptom>[],
    this.evidence = const <RepairEvidence>[],
    this.preferredRepairDate,
    this.preferredTimeStart,
    this.preferredTimeEnd,
    this.urgency = RepairUrgency.flexible,
    this.approximateArea = '',
    this.exactAddress = '',
    this.accessInstructions = '',
    this.travelDistanceKilometres = 25,
    this.collectionRequired = false,
    this.mobileRepairRequired = false,
    this.inspectionRequired = false,
    this.maximumCalloutFee,
    this.budgetMinimum,
    this.budgetMaximum,
  });

  factory RepairRequestDraft.fromJson(Map<String, Object?> json) {
    DateTime? date(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    List<Map<String, Object?>> maps(String key) {
      return (json[key] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    }

    return RepairRequestDraft(
      id: json['id']! as String,
      customerId: json['customerId']! as String,
      createdAt: date('createdAt') ?? DateTime.now(),
      updatedAt: date('updatedAt') ?? DateTime.now(),
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      status: RepairDraftStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => RepairDraftStatus.draft,
      ),
      categorySlug: json['categorySlug'] as String?,
      categoryLabel: json['categoryLabel'] as String?,
      subcategory: json['subcategory'] as String?,
      customCategory: json['customCategory'] as String?,
      itemName: json['itemName'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      approximateAgeYears: (json['approximateAgeYears'] as num?)?.toDouble(),
      serialNumber: json['serialNumber'] as String? ?? '',
      purchaseDate: date('purchaseDate'),
      warrantyStatus: json['warrantyStatus'] as String? ?? '',
      previousRepairs: json['previousRepairs'] as String? ?? '',
      itemLocation: json['itemLocation'] as String? ?? '',
      vehicleRegistration: json['vehicleRegistration'] as String? ?? '',
      vehicleMake: json['vehicleMake'] as String? ?? '',
      vehicleModel: json['vehicleModel'] as String? ?? '',
      vehicleYear: (json['vehicleYear'] as num?)?.toInt(),
      vehicleMileage: (json['vehicleMileage'] as num?)?.toInt(),
      vehicleFuelType: json['vehicleFuelType'] as String? ?? '',
      vehicleTransmission: json['vehicleTransmission'] as String? ?? '',
      problemDescription: json['problemDescription'] as String? ?? '',
      problemStarted: json['problemStarted'] as String? ?? '',
      problemOccurrence: json['problemOccurrence'] as String? ?? '',
      isWorsening: json['isWorsening'] as bool? ?? false,
      isStillUsable: json['isStillUsable'] as bool? ?? true,
      immediatePriorEvent: json['immediatePriorEvent'] as String? ?? '',
      symptoms: maps('symptoms').map(RepairSymptom.fromJson).toList(),
      evidence: maps('evidence').map(RepairEvidence.fromJson).toList(),
      preferredRepairDate: date('preferredRepairDate'),
      preferredTimeStart: json['preferredTimeStart'] as String?,
      preferredTimeEnd: json['preferredTimeEnd'] as String?,
      urgency: RepairUrgency.values.firstWhere(
        (value) => value.databaseValue == json['urgency'],
        orElse: () => RepairUrgency.flexible,
      ),
      approximateArea: json['approximateArea'] as String? ?? '',
      exactAddress: json['exactAddress'] as String? ?? '',
      accessInstructions: json['accessInstructions'] as String? ?? '',
      travelDistanceKilometres:
          (json['travelDistanceKilometres'] as num?)?.toDouble() ?? 25,
      collectionRequired: json['collectionRequired'] as bool? ?? false,
      mobileRepairRequired: json['mobileRepairRequired'] as bool? ?? false,
      inspectionRequired: json['inspectionRequired'] as bool? ?? false,
      maximumCalloutFee: (json['maximumCalloutFee'] as num?)?.toDouble(),
      budgetMinimum: (json['budgetMinimum'] as num?)?.toDouble(),
      budgetMaximum: (json['budgetMaximum'] as num?)?.toDouble(),
    );
  }

  factory RepairRequestDraft.empty({
    required String id,
    required String customerId,
    required DateTime now,
  }) {
    return RepairRequestDraft(
      id: id,
      customerId: customerId,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int currentStep;
  final RepairDraftStatus status;

  final String? categorySlug;
  final String? categoryLabel;
  final String? subcategory;
  final String? customCategory;

  final String itemName;
  final String brand;
  final String model;
  final double? approximateAgeYears;
  final String serialNumber;
  final DateTime? purchaseDate;
  final String warrantyStatus;
  final String previousRepairs;
  final String itemLocation;
  final String vehicleRegistration;
  final String vehicleMake;
  final String vehicleModel;
  final int? vehicleYear;
  final int? vehicleMileage;
  final String vehicleFuelType;
  final String vehicleTransmission;

  final String problemDescription;
  final String problemStarted;
  final String problemOccurrence;
  final bool isWorsening;
  final bool isStillUsable;
  final String immediatePriorEvent;
  final List<RepairSymptom> symptoms;
  final List<RepairEvidence> evidence;

  final DateTime? preferredRepairDate;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;
  final RepairUrgency urgency;
  final String approximateArea;
  final String exactAddress;
  final String accessInstructions;
  final double travelDistanceKilometres;
  final bool collectionRequired;
  final bool mobileRepairRequired;
  final bool inspectionRequired;
  final double? maximumCalloutFee;
  final double? budgetMinimum;
  final double? budgetMaximum;

  bool get isVehicle => categorySlug == 'vehicles';
  int get imageCount => evidence.where((item) => item.isImage).length;
  int get videoCount => evidence.where((item) => item.isVideo).length;
  int get audioCount => evidence.where((item) => item.isAudio).length;

  RepairRequestDraft copyWith({
    int? currentStep,
    RepairDraftStatus? status,
    String? categorySlug,
    String? categoryLabel,
    String? subcategory,
    String? customCategory,
    String? itemName,
    String? brand,
    String? model,
    double? approximateAgeYears,
    String? serialNumber,
    DateTime? purchaseDate,
    String? warrantyStatus,
    String? previousRepairs,
    String? itemLocation,
    String? vehicleRegistration,
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    int? vehicleMileage,
    String? vehicleFuelType,
    String? vehicleTransmission,
    String? problemDescription,
    String? problemStarted,
    String? problemOccurrence,
    bool? isWorsening,
    bool? isStillUsable,
    String? immediatePriorEvent,
    List<RepairSymptom>? symptoms,
    List<RepairEvidence>? evidence,
    DateTime? preferredRepairDate,
    String? preferredTimeStart,
    String? preferredTimeEnd,
    RepairUrgency? urgency,
    String? approximateArea,
    String? exactAddress,
    String? accessInstructions,
    double? travelDistanceKilometres,
    bool? collectionRequired,
    bool? mobileRepairRequired,
    bool? inspectionRequired,
    double? maximumCalloutFee,
    double? budgetMinimum,
    double? budgetMaximum,
    bool clearAge = false,
    bool clearPurchaseDate = false,
    bool clearVehicleYear = false,
    bool clearVehicleMileage = false,
    bool clearPreferredDate = false,
    bool clearPreferredTimeStart = false,
    bool clearPreferredTimeEnd = false,
    bool clearCalloutFee = false,
    bool clearBudgetMinimum = false,
    bool clearBudgetMaximum = false,
    DateTime? updatedAt,
  }) {
    return RepairRequestDraft(
      id: id,
      customerId: customerId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      subcategory: subcategory ?? this.subcategory,
      customCategory: customCategory ?? this.customCategory,
      itemName: itemName ?? this.itemName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      approximateAgeYears: clearAge
          ? null
          : approximateAgeYears ?? this.approximateAgeYears,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: clearPurchaseDate
          ? null
          : purchaseDate ?? this.purchaseDate,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      previousRepairs: previousRepairs ?? this.previousRepairs,
      itemLocation: itemLocation ?? this.itemLocation,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: clearVehicleYear ? null : vehicleYear ?? this.vehicleYear,
      vehicleMileage: clearVehicleMileage
          ? null
          : vehicleMileage ?? this.vehicleMileage,
      vehicleFuelType: vehicleFuelType ?? this.vehicleFuelType,
      vehicleTransmission: vehicleTransmission ?? this.vehicleTransmission,
      problemDescription: problemDescription ?? this.problemDescription,
      problemStarted: problemStarted ?? this.problemStarted,
      problemOccurrence: problemOccurrence ?? this.problemOccurrence,
      isWorsening: isWorsening ?? this.isWorsening,
      isStillUsable: isStillUsable ?? this.isStillUsable,
      immediatePriorEvent: immediatePriorEvent ?? this.immediatePriorEvent,
      symptoms: symptoms ?? this.symptoms,
      evidence: evidence ?? this.evidence,
      preferredRepairDate: clearPreferredDate
          ? null
          : preferredRepairDate ?? this.preferredRepairDate,
      preferredTimeStart: clearPreferredTimeStart
          ? null
          : preferredTimeStart ?? this.preferredTimeStart,
      preferredTimeEnd: clearPreferredTimeEnd
          ? null
          : preferredTimeEnd ?? this.preferredTimeEnd,
      urgency: urgency ?? this.urgency,
      approximateArea: approximateArea ?? this.approximateArea,
      exactAddress: exactAddress ?? this.exactAddress,
      accessInstructions: accessInstructions ?? this.accessInstructions,
      travelDistanceKilometres:
          travelDistanceKilometres ?? this.travelDistanceKilometres,
      collectionRequired: collectionRequired ?? this.collectionRequired,
      mobileRepairRequired: mobileRepairRequired ?? this.mobileRepairRequired,
      inspectionRequired: inspectionRequired ?? this.inspectionRequired,
      maximumCalloutFee: clearCalloutFee
          ? null
          : maximumCalloutFee ?? this.maximumCalloutFee,
      budgetMinimum: clearBudgetMinimum
          ? null
          : budgetMinimum ?? this.budgetMinimum,
      budgetMaximum: clearBudgetMaximum
          ? null
          : budgetMaximum ?? this.budgetMaximum,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'customerId': customerId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'currentStep': currentStep,
    'status': status.name,
    'categorySlug': categorySlug,
    'categoryLabel': categoryLabel,
    'subcategory': subcategory,
    'customCategory': customCategory,
    'itemName': itemName,
    'brand': brand,
    'model': model,
    'approximateAgeYears': approximateAgeYears,
    'serialNumber': serialNumber,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'warrantyStatus': warrantyStatus,
    'previousRepairs': previousRepairs,
    'itemLocation': itemLocation,
    'vehicleRegistration': vehicleRegistration,
    'vehicleMake': vehicleMake,
    'vehicleModel': vehicleModel,
    'vehicleYear': vehicleYear,
    'vehicleMileage': vehicleMileage,
    'vehicleFuelType': vehicleFuelType,
    'vehicleTransmission': vehicleTransmission,
    'problemDescription': problemDescription,
    'problemStarted': problemStarted,
    'problemOccurrence': problemOccurrence,
    'isWorsening': isWorsening,
    'isStillUsable': isStillUsable,
    'immediatePriorEvent': immediatePriorEvent,
    'symptoms': symptoms.map((item) => item.toJson()).toList(),
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'preferredRepairDate': preferredRepairDate?.toIso8601String(),
    'preferredTimeStart': preferredTimeStart,
    'preferredTimeEnd': preferredTimeEnd,
    'urgency': urgency.databaseValue,
    'approximateArea': approximateArea,
    'exactAddress': exactAddress,
    'accessInstructions': accessInstructions,
    'travelDistanceKilometres': travelDistanceKilometres,
    'collectionRequired': collectionRequired,
    'mobileRepairRequired': mobileRepairRequired,
    'inspectionRequired': inspectionRequired,
    'maximumCalloutFee': maximumCalloutFee,
    'budgetMinimum': budgetMinimum,
    'budgetMaximum': budgetMaximum,
  };
}
