import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => const AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isSignedIn;
});
