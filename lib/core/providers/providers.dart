import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/map_test_data.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/profile/services/profile_service.dart';
import '../../features/workspace/services/artist_workspace_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/artist_show.dart';
import '../../shared/models/gigbag_checklist.dart';
import '../../shared/models/music_release.dart';
import '../../shared/models/operational_task.dart';

/// Providers Riverpod para injeção de dependência
/// Escolha: Riverpod é moderno, type-safe, testável e não depende de BuildContext

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());
final artistWorkspaceServiceProvider =
    Provider<ArtistWorkspaceService>((ref) => ArtistWorkspaceService());

/// Perfil artista/banda usado nos módulos do painel (quando há vários perfis)
final dashboardWorkspaceProfileIdProvider = StateProvider<String?>((ref) => null);

final showsStreamProvider =
    StreamProvider.family<List<ArtistShow>, String>((ref, profileId) {
  return ref.watch(artistWorkspaceServiceProvider).showsStream(profileId);
});

final gigbagStreamProvider =
    StreamProvider.family<List<GigBagChecklist>, String>((ref, profileId) {
  return ref.watch(artistWorkspaceServiceProvider).gigbagStream(profileId);
});

final releasesStreamProvider =
    StreamProvider.family<List<MusicRelease>, String>((ref, profileId) {
  return ref.watch(artistWorkspaceServiceProvider).releasesStream(profileId);
});

final operationalTasksStreamProvider =
    StreamProvider.family<List<OperationalTask>, String>((ref, profileId) {
  return ref.watch(artistWorkspaceServiceProvider).operationalTasksStream(profileId);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final userProfilesProvider =
    StreamProvider.family<List<UserProfile>, String>((ref, userId) {
  return ref.watch(profileServiceProvider).profilesStreamForUser(userId);
});

final totalProfileCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.read(profileServiceProvider).getTotalProfileCount();
});

final mapLocationCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final realCounts = await ref.read(profileServiceProvider).getLocationCountsByState();
  if (!MapTestData.enableMapTestPins) return realCounts;

  final merged = Map<String, int>.from(realCounts);
  for (final e in MapTestData.testStateCounts.entries) {
    merged[e.key] = (merged[e.key] ?? 0) + e.value;
  }
  return merged;
});

final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, profileId) {
  return ref.watch(profileServiceProvider).profileStream(profileId);
});

final userAccountTypeProvider =
    FutureProvider.autoDispose.family<String, String>((ref, userId) async {
  return ref.read(profileServiceProvider).getUserAccountType(userId);
});

final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.read(profileServiceProvider).isAdmin(user.uid, user.email);
});

final profileViewCountProvider =
    StreamProvider.family<int, String>((ref, profileId) {
  return ref.watch(profileServiceProvider).profileViewCountStream(profileId);
});
