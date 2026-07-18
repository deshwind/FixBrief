import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';

part 'repair_draft_database.g.dart';

class RepairDraftRecords extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()();
  IntColumn get currentStep => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[RepairDraftRecords])
class RepairDraftDatabase extends _$RepairDraftDatabase {
  RepairDraftDatabase() : super(driftDatabase(name: 'fixbrief_drafts'));

  RepairDraftDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<RepairRequestDraft?> loadActiveDraft(String customerId) async {
    final row =
        await (select(repairDraftRecords)
              ..where(
                (table) =>
                    table.customerId.equals(customerId) &
                    table.status.equals(RepairDraftStatus.draft.name),
              )
              ..orderBy(<OrderingTerm Function(RepairDraftRecords)>[
                (table) => OrderingTerm.desc(table.updatedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return RepairRequestDraft.fromJson(
      (jsonDecode(row.payloadJson) as Map<Object?, Object?>).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<void> saveDraft(RepairRequestDraft draft) async {
    await into(repairDraftRecords).insertOnConflictUpdate(
      RepairDraftRecordsCompanion.insert(
        id: draft.id,
        customerId: draft.customerId,
        payloadJson: jsonEncode(draft.toJson()),
        status: draft.status.name,
        currentStep: draft.currentStep,
        updatedAt: draft.updatedAt,
      ),
    );
  }

  Future<void> deleteDraft(String draftId) async {
    await (delete(
      repairDraftRecords,
    )..where((row) => row.id.equals(draftId))).go();
  }
}
