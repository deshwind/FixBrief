import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';

abstract final class RepairRequestValidation {
  static String? stepError(RepairRequestDraft draft, int step) {
    return switch (step) {
      0 => _category(draft),
      1 => _item(draft),
      2 => _problem(draft),
      3 => null,
      4 => firstIncompleteError(draft),
      5 => _publishing(draft),
      _ => null,
    };
  }

  static String? firstIncompleteError(RepairRequestDraft draft) {
    return _category(draft) ?? _item(draft) ?? _problem(draft);
  }

  static String? submissionError(RepairRequestDraft draft) {
    return firstIncompleteError(draft) ?? _publishing(draft);
  }

  static String? _category(RepairRequestDraft draft) {
    if (draft.categorySlug == null) {
      return 'Choose a repair category.';
    }
    if (draft.categorySlug == 'other' &&
        (draft.customCategory?.trim().length ?? 0) < 2) {
      return 'Describe the repair category.';
    }
    return null;
  }

  static String? _item(RepairRequestDraft draft) {
    if (draft.itemName.trim().length < 2) {
      return 'Enter the item that needs repairing.';
    }
    if (draft.isVehicle && draft.vehicleRegistration.trim().isEmpty) {
      return 'Enter the vehicle registration, or “Unknown”.';
    }
    return null;
  }

  static String? _problem(RepairRequestDraft draft) {
    final hasDescription = draft.problemDescription.trim().length >= 10;
    final hasSymptoms = draft.symptoms.any(
      (symptom) => symptom.description.trim().isNotEmpty,
    );
    final hasAudio = draft.evidence.any((item) => item.isAudio);
    if (!hasDescription && !hasSymptoms && !hasAudio) {
      return 'Describe the problem, choose a symptom, or add an audio note.';
    }
    return null;
  }

  static String? _publishing(RepairRequestDraft draft) {
    if (draft.approximateArea.trim().length < 2) {
      return 'Enter the town or postcode area shown to repairers.';
    }
    if (draft.exactAddress.trim().length < 5) {
      return 'Enter the private repair address.';
    }
    if (draft.budgetMinimum != null &&
        draft.budgetMaximum != null &&
        draft.budgetMinimum! > draft.budgetMaximum!) {
      return 'The minimum budget cannot exceed the maximum budget.';
    }
    return null;
  }
}
