import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fixbrief/features/repair_requests/data/local/repair_draft_database.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/domain/repositories/repair_request_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepairRequestRepository implements RepairRequestRepository {
  SupabaseRepairRequestRepository(this._client, this._database);

  final SupabaseClient _client;
  final RepairDraftDatabase _database;

  @override
  Future<RepairRequestDraft?> loadActiveDraft(String customerId) {
    return _database.loadActiveDraft(customerId);
  }

  @override
  Future<void> saveDraft(RepairRequestDraft draft) {
    return _database.saveDraft(draft);
  }

  @override
  Future<void> discardDraft(String draftId) {
    return _database.deleteDraft(draftId);
  }

  @override
  Future<String> submit(
    RepairRequestDraft draft, {
    required bool isOnline,
    EvidenceStatusCallback? onEvidenceStatus,
  }) async {
    if (!isOnline) {
      throw const RepairRequestFailure(
        'You are offline. Your draft is safe and will not be submitted yet.',
      );
    }

    try {
      final categoryId = await _catalogueId(
        'repair_categories',
        'slug',
        _databaseCategorySlug(draft),
      );
      final subcategoryId = draft.subcategory == null
          ? null
          : await _subcategoryId(categoryId, draft.subcategory!);

      await _client.from('repair_requests').upsert(<String, Object?>{
        'id': draft.id,
        'client_request_id': draft.id,
        'customer_id': draft.customerId,
        'category_id': categoryId,
        'subcategory_id': subcategoryId,
        'custom_category': draft.categorySlug == 'other'
            ? _nullable(draft.customCategory ?? '')
            : null,
        'item_name': draft.itemName.trim(),
        'brand': _nullable(draft.brand),
        'model': _nullable(draft.model),
        'approximate_age_years': draft.approximateAgeYears,
        'serial_number': _nullable(draft.serialNumber),
        'purchase_date': _date(draft.purchaseDate),
        'warranty_status': _nullable(draft.warrantyStatus),
        'previous_repairs': _nullable(draft.previousRepairs),
        'item_location_label': _nullable(draft.itemLocation),
        'vehicle_registration': draft.isVehicle
            ? _nullable(draft.vehicleRegistration)
            : null,
        'vehicle_make': draft.isVehicle ? _nullable(draft.vehicleMake) : null,
        'vehicle_model': draft.isVehicle ? _nullable(draft.vehicleModel) : null,
        'vehicle_year': draft.isVehicle ? draft.vehicleYear : null,
        'vehicle_mileage': draft.isVehicle ? draft.vehicleMileage : null,
        'vehicle_fuel_type': draft.isVehicle
            ? _nullable(draft.vehicleFuelType)
            : null,
        'vehicle_transmission': draft.isVehicle
            ? _nullable(draft.vehicleTransmission)
            : null,
        'problem_description': draft.problemDescription.trim(),
        'preferred_repair_date': _date(draft.preferredRepairDate),
        'preferred_time_start': draft.preferredTimeStart,
        'preferred_time_end': draft.preferredTimeEnd,
        'urgency': draft.urgency.databaseValue,
        'approximate_area': draft.approximateArea.trim(),
        'travel_distance_kilometres': draft.travelDistanceKilometres,
        'collection_required': draft.collectionRequired,
        'mobile_repair_required': draft.mobileRepairRequired,
        'inspection_required': draft.inspectionRequired,
        'maximum_callout_fee_minor': _minor(draft.maximumCalloutFee),
        'budget_minimum_minor': _minor(draft.budgetMinimum),
        'budget_maximum_minor': _minor(draft.budgetMaximum),
        'status': 'draft',
      }, onConflict: 'id');

      await _replaceSymptoms(draft);
      await _savePrivateLocation(draft);
      for (final evidence in draft.evidence) {
        onEvidenceStatus?.call(
          evidence.id,
          EvidenceUploadStatus.uploading,
          null,
        );
        try {
          await _uploadEvidence(draft, evidence);
          onEvidenceStatus?.call(evidence.id, EvidenceUploadStatus.ready, null);
        } on Object {
          onEvidenceStatus?.call(
            evidence.id,
            EvidenceUploadStatus.failed,
            'Upload interrupted. Retry when your connection is stable.',
          );
          rethrow;
        }
      }

      await _client
          .from('repair_requests')
          .update(<String, Object?>{'status': 'submitted'})
          .eq('id', draft.id);

      await _database.saveDraft(
        draft.copyWith(status: RepairDraftStatus.submitted),
      );
      return draft.id;
    } on RepairRequestFailure {
      rethrow;
    } on Object catch (_) {
      throw const RepairRequestFailure(
        'We could not submit the request. Your draft is safe—please retry.',
      );
    }
  }

  Future<String> _catalogueId(String table, String column, String value) async {
    final row = await _client
        .from(table)
        .select('id')
        .eq(column, value)
        .maybeSingle();
    if (row == null) {
      throw const RepairRequestFailure(
        'The selected repair category is not available yet.',
      );
    }
    return row['id']! as String;
  }

  Future<String?> _subcategoryId(String categoryId, String label) async {
    final row = await _client
        .from('repair_subcategories')
        .select('id')
        .eq('category_id', categoryId)
        .ilike('name', label)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<void> _replaceSymptoms(RepairRequestDraft draft) async {
    await _client
        .from('repair_request_symptoms')
        .delete()
        .eq('request_id', draft.id);
    if (draft.symptoms.isEmpty) {
      return;
    }
    await _client.from('repair_request_symptoms').insert(<Map<String, Object?>>[
      for (var index = 0; index < draft.symptoms.length; index++)
        <String, Object?>{
          'id': draft.symptoms[index].id,
          'request_id': draft.id,
          'kind': draft.symptoms[index].kind.databaseValue,
          'description': draft.symptoms[index].description.trim(),
          'source': draft.symptoms[index].source.databaseValue,
          'sort_order': index,
        },
    ]);
  }

  Future<void> _savePrivateLocation(RepairRequestDraft draft) async {
    await _client
        .from('repair_request_private_locations')
        .upsert(<String, Object?>{
          'request_id': draft.id,
          'customer_id': draft.customerId,
          'exact_address': draft.exactAddress.trim(),
          'access_instructions': _nullable(draft.accessInstructions),
        }, onConflict: 'request_id');
  }

  Future<void> _uploadEvidence(
    RepairRequestDraft draft,
    RepairEvidence evidence,
  ) async {
    final file = File(evidence.localPath);
    if (!await file.exists()) {
      throw RepairRequestFailure(
        '${evidence.filename} is no longer available on this device.',
      );
    }
    final bucket = _bucketFor(evidence);
    final extension = _safeExtension(evidence.filename);
    final path = '${draft.customerId}/${draft.id}/${evidence.id}$extension';
    final checksum = sha256.convert(await file.readAsBytes()).toString();

    await _client.from('repair_request_media').upsert(<String, Object?>{
      'id': evidence.id,
      'request_id': draft.id,
      'uploaded_by': draft.customerId,
      'kind': evidence.kind.databaseValue,
      'bucket_name': bucket,
      'object_path': path,
      'original_filename': evidence.filename,
      'mime_type': evidence.mimeType,
      'byte_size': evidence.byteSize,
      'checksum_sha256': checksum,
      'sort_order': evidence.sortOrder,
      'upload_status': 'uploading',
      'failure_reason': null,
    }, onConflict: 'id');

    await _client.storage
        .from(bucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: evidence.mimeType,
            upsert: true,
          ),
          retryAttempts: 3,
        );
    await _client
        .from('repair_request_media')
        .update(<String, Object?>{
          'upload_status': 'ready',
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', evidence.id);
    if (evidence.isAudio && await file.exists()) {
      await file.delete();
    }
  }

  String _bucketFor(RepairEvidence evidence) {
    if (evidence.isVideo) {
      return 'repair-request-videos';
    }
    if (evidence.isAudio) {
      return 'repair-request-audio';
    }
    if (evidence.kind == RepairEvidenceKind.image || evidence.isImage) {
      return 'repair-request-images';
    }
    return 'repair-request-documents';
  }

  String _safeExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    final extension = filename.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension) ? extension : '';
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _date(DateTime? value) {
    if (value == null) {
      return null;
    }
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  int? _minor(double? pounds) => pounds == null ? null : (pounds * 100).round();

  String _databaseCategorySlug(RepairRequestDraft draft) {
    final subcategory = draft.subcategory?.toLowerCase() ?? '';
    return switch (draft.categorySlug) {
      'vehicles' => subcategory.contains('motorcycle') ? 'motorcycles' : 'cars',
      'appliances' => switch (subcategory) {
        'washing machine' => 'washing-machines',
        'dishwasher' => 'dishwashers',
        'fridge/freezer' => 'refrigerators',
        'oven' => 'cookers-and-ovens',
        _ => 'other',
      },
      'computers' => switch (subcategory) {
        'laptop' => 'laptops',
        'phone' => 'phones',
        'tablet' => 'tablets',
        'desktop' => 'computers',
        _ => 'other',
      },
      'property' => switch (subcategory) {
        'door/window' => 'doors-and-windows',
        'roof' => 'roofing',
        'heating' => 'heating',
        _ => 'property-damage',
      },
      'industrial' => 'industrial-equipment',
      final String slug => slug,
      null => 'other',
    };
  }
}
