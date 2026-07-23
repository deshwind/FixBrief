import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mock_services.dart';

void main() {
  group('Stage 12 external-service mocks', () {
    test('Supabase database and storage can be isolated', () {
      final client = MockSupabaseClient();
      final storage = MockSupabaseStorageClient();
      when(() => client.storage).thenReturn(storage);

      expect(client.storage, same(storage));
      verify(() => client.storage).called(1);
    });

    test(
      'connectivity and location can be controlled without a device',
      () async {
        final connectivity = MockConnectivity();
        final location = MockGeolocatorPlatform();
        when(connectivity.checkConnectivity).thenAnswer(
          (_) async => <ConnectivityResult>[ConnectivityResult.wifi],
        );
        when(
          location.checkPermission,
        ).thenAnswer((_) async => LocationPermission.whileInUse);

        expect(await connectivity.checkConnectivity(), <ConnectivityResult>[
          ConnectivityResult.wifi,
        ]);
        expect(await location.checkPermission(), LocationPermission.whileInUse);
      },
    );

    test('media selection can return deterministic private evidence', () async {
      final picker = MockRepairMediaPicker();
      const evidence = RepairEvidence(
        id: 'evidence-1',
        kind: RepairEvidenceKind.image,
        localPath: 'C:/private/evidence/photo.jpg',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        byteSize: 1024,
        sortOrder: 0,
      );
      when(
        picker.pickPhotos,
      ).thenAnswer((_) async => <RepairEvidence>[evidence]);
      when(
        () => picker.deleteLocal(evidence.localPath),
      ).thenAnswer((_) async {});

      final selected = await picker.pickPhotos();
      await picker.deleteLocal(selected.single.localPath);

      expect(selected, <RepairEvidence>[evidence]);
      verify(() => picker.deleteLocal(evidence.localPath)).called(1);
    });

    test(
      'AI failures can be exercised without making a network call',
      () async {
        final repository = MockAiAssessmentRepository();
        const request = AiAssessmentRequest(
          requestId: 'request-1',
          category: 'Computers',
          subcategory: 'Laptop',
          itemName: 'Laptop',
          brand: '',
          model: '',
          problemDescription: 'The laptop overheats after ten minutes.',
          previousRepairs: '',
          isStillUsable: true,
          isWorsening: true,
          symptoms: <String>['Hot case', 'Loud fan'],
          evidenceKinds: <String>[],
        );
        when(() => repository.generate(request)).thenThrow(
          const AiAssessmentFailure(
            'AI is temporarily unavailable. Try again.',
          ),
        );

        expect(
          () => repository.generate(request),
          throwsA(
            isA<AiAssessmentFailure>().having(
              (value) => value.message,
              'message',
              'AI is temporarily unavailable. Try again.',
            ),
          ),
        );
      },
    );
  });
}
