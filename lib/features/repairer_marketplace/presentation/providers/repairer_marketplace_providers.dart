import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/repairer_marketplace/data/repositories/demo_repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/data/repositories/supabase_repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/repositories/repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/controllers/repairer_marketplace_controller.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/controllers/repairer_marketplace_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final repairerMarketplaceRepositoryProvider =
    Provider<RepairerMarketplaceRepository>((ref) {
      if (ref.watch(appEnvironmentProvider).useDemoAuthentication) {
        return DemoRepairerMarketplaceRepository();
      }
      return SupabaseRepairerMarketplaceRepository(
        ref.watch(supabaseClientProvider),
      );
    });

final repairerMarketplaceControllerProvider =
    NotifierProvider<RepairerMarketplaceController, RepairerMarketplaceState>(
      RepairerMarketplaceController.new,
    );

final marketplaceRequestDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceRequestDetail, String>((ref, requestId) {
      return ref
          .watch(repairerMarketplaceRepositoryProvider)
          .loadRequest(requestId);
    });

final repairerMarketplaceProfileProvider = FutureProvider.autoDispose
    .family<RepairerMarketplaceProfile, String?>((ref, repairerId) {
      return ref
          .watch(repairerMarketplaceRepositoryProvider)
          .loadProfile(repairerId: repairerId);
    });
