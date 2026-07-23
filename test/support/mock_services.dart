import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:fixbrief/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:fixbrief/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:fixbrief/features/repair_requests/data/services/repair_media_services.dart';
import 'package:fixbrief/features/repair_requests/domain/repositories/repair_request_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockConnectivity extends Mock implements Connectivity {}

class MockGeolocatorPlatform extends Mock implements GeolocatorPlatform {}

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockAiAssessmentRepository extends Mock
    implements AiAssessmentRepository {}

class MockRepairRequestRepository extends Mock
    implements RepairRequestRepository {}

class MockRepairMediaPicker extends Mock implements RepairMediaPicker {}

class MockRepairSpeechService extends Mock implements RepairSpeechService {}

class MockRepairAudioRecorder extends Mock implements RepairAudioRecorder {}
