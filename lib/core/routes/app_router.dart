import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/pages/admin_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/landing/pages/landing_page.dart';
import '../../features/legal/pages/privacy_page.dart';
import '../../features/legal/pages/terms_page.dart';
import '../../features/profile/pages/complete_profile_page.dart';
import '../../features/profile/pages/edit_profile_page.dart';
import '../../features/public/pages/public_artist_page.dart';
import '../providers/providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router principal com GoRouter
/// Proteção de rotas: dashboard e edit-profile exigem auth + perfil completo
GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final authState = ref.read(authStateProvider);
      final user = authState.valueOrNull ??
          ref.read(authServiceProvider).currentUser;

      final loc = state.matchedLocation;
      final isDashboard = loc == '/dashboard';
      final isEditProfile = loc.startsWith('/edit-profile');
      final isCompleteProfile = loc.startsWith('/complete-profile');
      final isAdminRoute = loc.startsWith('/admin');

      if (user == null) {
        if (isDashboard || isEditProfile || isCompleteProfile || isAdminRoute) {
          return '/login';
        }
        return null;
      }

      if (isAdminRoute) {
        final admin = await ref.read(profileServiceProvider).isAdmin(user.uid, user.email);
        if (!admin) return '/dashboard';
        return null;
      }

      final profiles =
          await ref.read(profileServiceProvider).getProfilesForUser(user.uid);

      if (profiles.isEmpty && !isCompleteProfile && (isDashboard || isEditProfile)) {
        return '/complete-profile';
      }

      if (isEditProfile) {
        final profileId = state.pathParameters['profileId'];
        if (profileId != null) {
          final profile = await ref.read(profileServiceProvider).getProfile(profileId);
          if (profile == null || profile.ownerUserId != user.uid) {
            return '/dashboard';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/artist/:profileId',
        builder: (context, state) {
          final id = state.pathParameters['profileId'] ?? '';
          return PublicArtistPage(profileId: id);
        },
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (_, __) => const CompleteProfilePage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminPage(),
      ),
      GoRoute(
        path: '/edit-profile/:profileId',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'] ?? '';
          return EditProfilePage(profileId: profileId);
        },
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const TermsPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => const PrivacyPage(),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(ref);
  ref.listen(authStateProvider, (_, __) => router.refresh());
  return router;
});
