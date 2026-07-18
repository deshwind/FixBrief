import 'package:fixbrief/features/authentication/presentation/controllers/auth_session_controller.dart';
import 'package:fixbrief/features/authentication/presentation/controllers/auth_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authSessionControllerProvider =
    NotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );
