import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/firebase/app_firebase_database.dart';
import '../../../../core/firebase/rtdb_rest_client.dart';
import '../../../../core/utils/profile_lookup.dart';
import '../../../../shared/models/user_profile.dart';

/// Serviço de perfil com Firebase Realtime Database
/// Um usuário pode ter vários perfis (várias bandas/artistas)
class ProfileService {
  final DatabaseReference _db = appFirebaseDatabase.ref();

  /// No Web o [FirebaseException.code] costuma ser `firebase_database/permission-denied`,
  /// não só `permission-denied` — comparação estrita impedia o fallback REST.
  static bool _isRtdbPermissionDenied(Object e) {
    if (e is FirebaseException) {
      return e.code.toLowerCase().contains('permission-denied');
    }
    return e.toString().toLowerCase().contains('permission-denied');
  }

  /// Garante sessão válida e token JWT atualizado (evita permission-denied no RTDB Web).
  Future<void> _refreshAuthTokenForRtdb() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('not_authenticated');
    }
    await u.getIdToken(true);
    final db = appFirebaseDatabase;
    try {
      db.goOffline();
      db.goOnline();
    } catch (_) {
      // Algumas plataformas podem não suportar; token já foi renovado
    }
  }

  /// Mobile/desktop: SDK + retry + REST. No Web, [saveProfile] usa REST direto.
  Future<void> _setProfileOrRetry(String profileId, Map<String, dynamic> profileData) async {
    final ref = _db.child(AppConstants.profilesPath).child(profileId);
    try {
      await ref.set(profileData);
      return;
    } catch (e) {
      if (!_isRtdbPermissionDenied(e)) rethrow;
    }
    await _refreshAuthTokenForRtdb();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await ref.set(profileData);
      return;
    } catch (e) {
      if (!_isRtdbPermissionDenied(e)) rethrow;
    }
    await RtdbRestClient.putJson(
      '${AppConstants.profilesPath}/$profileId',
      profileData,
    );
  }

  /// Verifica se o limite de vagas do pré-lançamento foi atingido
  Future<bool> isAtEarlyAccessLimit() async {
    final total = await getTotalProfileCount();
    final count = AppConstants.earlyAccessReserved + total;
    return count >= AppConstants.earlyAccessLimit;
  }

  /// Busca perfil duplicado por nome + Instagram (normalizados)
  /// Retorna o perfil existente se encontrar, null caso contrário
  Future<UserProfile?> findDuplicateProfile(String artistName, String instagram) async {
    await _refreshAuthTokenForRtdb();
    final key = normalizeProfileLookupKey(artistName, instagram);
    final Map<dynamic, dynamic> data;
    if (kIsWeb) {
      final raw = await RtdbRestClient.getJson(AppConstants.profilesPath);
      if (raw == null) return null;
      if (raw is! Map) return null;
      data = raw;
    } else {
      final snapshot = await _db.child(AppConstants.profilesPath).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      data = snapshot.value as Map<dynamic, dynamic>;
    }
    for (final entry in data.entries) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      final existingKey = normalizeProfileLookupKey(
        map['artistName']?.toString() ?? '',
        map['instagram']?.toString() ?? '',
      );
      if (existingKey == key) {
        return UserProfile.fromMap(entry.key as String, map);
      }
    }
    return null;
  }

  /// Cria ou atualiza perfil
  /// Se profile.id estiver vazio, cria novo
  /// Lança StateError se limite de vagas atingido (apenas para novo perfil)
  Future<String> saveProfile(UserProfile profile) async {
    await _refreshAuthTokenForRtdb();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (profile.ownerUserId != uid) {
      throw StateError('owner_mismatch');
    }

    final isNew = profile.id.isEmpty;
    if (isNew) {
      final atLimit = await isAtEarlyAccessLimit();
      if (atLimit) {
        throw StateError('early_access_limit_reached');
      }
    }
    final profileId = isNew ? _db.child(AppConstants.profilesPath).push().key! : profile.id;

    final profileData = profile.toMap();

    if (kIsWeb) {
      await RtdbRestClient.putJson(
        '${AppConstants.profilesPath}/$profileId',
        profileData,
      );
      if (isNew) {
        try {
          await RtdbRestClient.putJson(
            '${AppConstants.profilesByOwnerPath}/${profile.ownerUserId}/$profileId',
            true,
          );
        } catch (e) {
          try {
            await RtdbRestClient.delete('${AppConstants.profilesPath}/$profileId');
          } catch (_) {}
          rethrow;
        }
        try {
          await RtdbRestClient.incrementAtPath(AppConstants.totalProfilesPath, 1);
        } catch (_) {}
      }
    } else {
      await _setProfileOrRetry(profileId, profileData);
      if (isNew) {
        try {
          await _db
              .child(AppConstants.profilesByOwnerPath)
              .child(profile.ownerUserId)
              .child(profileId)
              .set(true);
        } on FirebaseException catch (e) {
          if (_isRtdbPermissionDenied(e)) {
            try {
              await RtdbRestClient.putJson(
                '${AppConstants.profilesByOwnerPath}/${profile.ownerUserId}/$profileId',
                true,
              );
            } catch (_) {
              try {
                await _db.child(AppConstants.profilesPath).child(profileId).remove();
              } catch (_) {
                try {
                  await RtdbRestClient.delete('${AppConstants.profilesPath}/$profileId');
                } catch (_) {}
              }
              rethrow;
            }
          } else {
            try {
              await _db.child(AppConstants.profilesPath).child(profileId).remove();
            } catch (_) {
              try {
                await RtdbRestClient.delete('${AppConstants.profilesPath}/$profileId');
              } catch (_) {}
            }
            rethrow;
          }
        } catch (e) {
          try {
            await _db.child(AppConstants.profilesPath).child(profileId).remove();
          } catch (_) {
            try {
              await RtdbRestClient.delete('${AppConstants.profilesPath}/$profileId');
            } catch (_) {}
          }
          rethrow;
        }
        try {
          await _db.child(AppConstants.totalProfilesPath).set(ServerValue.increment(1));
        } catch (_) {}
      }
    }

    return profileId;
  }

  /// Stream de um perfil específico
  Stream<UserProfile?> profileStream(String profileId) {
    return _db
        .child(AppConstants.profilesPath)
        .child(profileId)
        .onValue
        .map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return UserProfile.fromMap(
          profileId,
          Map<String, dynamic>.from(event.snapshot.value as Map),
        );
      }
      return null;
    });
  }

  /// Busca perfil pelo profileId
  Future<UserProfile?> getProfile(String profileId) async {
    final snapshot = await _db
        .child(AppConstants.profilesPath)
        .child(profileId)
        .get();

    if (snapshot.exists && snapshot.value != null) {
      return UserProfile.fromMap(profileId, Map<String, dynamic>.from(snapshot.value as Map));
    }
    return null;
  }

  /// Lista todos os perfis do usuário
  Future<List<UserProfile>> getProfilesForUser(String userId) async {
    final snapshot = await _db
        .child(AppConstants.profilesByOwnerPath)
        .child(userId)
        .get();

    if (snapshot.exists && snapshot.value != null) {
      final profileIds =
          Map<String, dynamic>.from(snapshot.value as Map).keys.cast<String>();
    final profiles = <UserProfile>[];

    for (final id in profileIds) {
      final profile = await getProfile(id);
      if (profile != null) profiles.add(profile);
    }

      profiles.sort((a, b) => a.artistName.compareTo(b.artistName));
      return profiles;
    }

    final legacySnapshot =
        await _db.child(AppConstants.profilesPath).child(userId).get();
    if (legacySnapshot.exists && legacySnapshot.value != null) {
      final p = UserProfile.fromMap(
        userId,
        Map<String, dynamic>.from(legacySnapshot.value as Map),
        ownerUserIdOverride: userId,
      );
      return [p];
    }
    return [];
  }

  /// Stream dos perfis do usuário (reativo)
  Stream<List<UserProfile>> profilesStreamForUser(String userId) {
    return _db
        .child(AppConstants.profilesByOwnerPath)
        .child(userId)
        .onValue
        .asyncMap((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final profileIds =
            Map<String, dynamic>.from(event.snapshot.value as Map).keys.cast<String>();
        final profiles = <UserProfile>[];
        for (final id in profileIds) {
          final profile = await getProfile(id);
          if (profile != null) profiles.add(profile);
        }
        profiles.sort((a, b) => a.artistName.compareTo(b.artistName));
        return profiles;
      }
      final legacySnapshot =
          await _db.child(AppConstants.profilesPath).child(userId).get();
      if (legacySnapshot.exists && legacySnapshot.value != null) {
        final p = UserProfile.fromMap(
          userId,
          Map<String, dynamic>.from(legacySnapshot.value as Map),
          ownerUserIdOverride: userId,
        );
        return [p];
      }
      return [];
    });
  }

  /// Atualiza flag profileCompleted no nó users
  /// Se o nó não existir (ex.: conta Google sem `createUserRecord`), cria registro mínimo.
  Future<void> markProfileCompleted(String userId) async {
    await _refreshAuthTokenForRtdb();
    if (FirebaseAuth.instance.currentUser!.uid != userId) {
      throw StateError('owner_mismatch');
    }
    final now = DateTime.now().toIso8601String();
    if (kIsWeb) {
      final existing = await RtdbRestClient.getJson('${AppConstants.usersPath}/$userId');
      if (existing is Map && existing.isNotEmpty) {
        await RtdbRestClient.patchJson('${AppConstants.usersPath}/$userId', {
          'profileCompleted': true,
          'updatedAt': now,
        });
      } else {
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        await RtdbRestClient.putJson('${AppConstants.usersPath}/$userId', {
          'email': email,
          'accountType': 'person',
          'createdAt': now,
          'updatedAt': now,
          'profileCompleted': true,
        });
      }
      return;
    }
    final ref = _db.child(AppConstants.usersPath).child(userId);
    final snap = await ref.get();
    if (snap.exists && snap.value != null) {
      try {
        await ref.update({
          'profileCompleted': true,
          'updatedAt': now,
        });
      } catch (e) {
        if (!_isRtdbPermissionDenied(e)) rethrow;
        await RtdbRestClient.patchJson('${AppConstants.usersPath}/$userId', {
          'profileCompleted': true,
          'updatedAt': now,
        });
      }
    } else {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      final payload = {
        'email': email,
        'accountType': 'person',
        'createdAt': now,
        'updatedAt': now,
        'profileCompleted': true,
      };
      try {
        await ref.set(payload);
      } catch (e) {
        if (!_isRtdbPermissionDenied(e)) rethrow;
        await RtdbRestClient.putJson('${AppConstants.usersPath}/$userId', payload);
      }
    }
  }

  /// Retorna o total de bandas/artistas cadastradas (apenas dados reais do banco)
  /// Lê de stats/totalProfiles (público) para exibir na landing para visitantes
  Future<int> getTotalProfileCount() async {
    final snapshot = await _db.child(AppConstants.totalProfilesPath).get();
    if (!snapshot.exists || snapshot.value == null) return 0;
    final v = snapshot.value;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Retorna contagem de bandas/artistas por estado (visualização no Brasil)
  Future<Map<String, int>> getLocationCountsByState() async {
    final snapshot = await _db.child(AppConstants.profilesPath).get();
    if (!snapshot.exists || snapshot.value == null) return {};

    final data = snapshot.value as Map<dynamic, dynamic>;
    final counts = <String, int>{};

    for (final entry in data.values) {
      final map = Map<String, dynamic>.from(entry as Map);
      final state = (map['state'] as String? ?? '').toUpperCase().trim();
      if (state.length == 2) {
        counts[state] = (counts[state] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Cria/atualiza registro básico do usuário (chamado no sign up)
  /// accountType: 'band' (conta da banda) ou 'person' (pessoa que gerencia bandas)
  Future<void> createUserRecord(
    String userId,
    String email, {
    String accountType = 'person',
    String? representationDeclarationAcceptedAt,
    String? referralSource,
  }) async {
    final ref = _db.child(AppConstants.usersPath).child(userId);
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'email': email,
      'accountType': accountType,
      'createdAt': now,
      'updatedAt': now,
      'profileCompleted': false,
    };
    if (representationDeclarationAcceptedAt != null) {
      data['representationDeclarationAcceptedAt'] = representationDeclarationAcceptedAt;
    }
    if (referralSource != null && referralSource.trim().isNotEmpty) {
      data['referralSource'] = referralSource.trim();
    }
    await ref.set(data);
  }

  /// Origem do cadastro (`?ref=`), para o admin
  Future<String?> getUserReferralSource(String userId) async {
    final snapshot =
        await _db.child(AppConstants.usersPath).child(userId).child('referralSource').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return snapshot.value.toString();
  }

  /// Visualizações do link público (incrementado por Cloud Function)
  Stream<int> profileViewCountStream(String profileId) {
    return _db
        .child(AppConstants.profileViewsPath)
        .child(profileId)
        .onValue
        .map((event) {
      final v = event.snapshot.value;
      if (v is num) return v.toInt();
      return 0;
    });
  }

  Future<int> getProfileViewCount(String profileId) async {
    final snapshot = await _db.child(AppConstants.profileViewsPath).child(profileId).get();
    final v = snapshot.value;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Retorna o tipo de conta do usuário
  Future<String> getUserAccountType(String userId) async {
    final snapshot = await _db.child(AppConstants.usersPath).child(userId).get();
    if (!snapshot.exists || snapshot.value == null) return 'person';
    final map = Map<String, dynamic>.from(snapshot.value as Map);
    final type = map['accountType'] as String? ?? 'person';
    return type == 'band' ? 'band' : 'person';
  }

  /// Lista [AppConstants.adminEmails] ou nó `admin_users/{uid}` no Realtime Database
  Future<bool> isAdmin(String uid, String? email) async {
    final e = email?.toLowerCase().trim();
    if (e != null && e.isNotEmpty) {
      for (final a in AppConstants.adminEmails) {
        if (a.toLowerCase().trim() == e) return true;
      }
    }
    final snap = await _db.child(AppConstants.adminUsersPath).child(uid).get();
    if (!snap.exists || snap.value == null) return false;
    final v = snap.value;
    return v == true || v == 'true';
  }

  /// Lista todos os perfis (uso interno / admin)
  Future<List<UserProfile>> getAllProfiles() async {
    final snapshot = await _db.child(AppConstants.profilesPath).get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    final list = <UserProfile>[];
    for (final entry in data.entries) {
      list.add(
        UserProfile.fromMap(
          entry.key as String,
          Map<String, dynamic>.from(entry.value as Map),
        ),
      );
    }
    list.sort((a, b) => a.artistName.compareTo(b.artistName));
    return list;
  }

  /// Desativa todos os perfis e marca a conta como inativa (soft delete)
  Future<void> deactivateUserAccount(String userId) async {
    final profiles = await getProfilesForUser(userId);
    final now = DateTime.now();
    for (final p in profiles) {
      final updated = p.copyWith(
        status: 'inactive',
        publicProfile: false,
        updatedAt: now,
      );
      await _db.child(AppConstants.profilesPath).child(p.id).set(updated.toMap());
    }
    await _db.child(AppConstants.usersPath).child(userId).update({
      'accountStatus': 'inactive',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Remove perfis, vínculos e registro do usuário no Realtime Database
  Future<void> deleteUserDatabaseData(String userId) async {
    final profiles = await getProfilesForUser(userId);
    for (final p in profiles) {
      await _db.child(AppConstants.profilesPath).child(p.id).remove();
      try {
        await _db.child(AppConstants.profileViewsPath).child(p.id).remove();
      } catch (_) {}
      try {
        await _db.child(AppConstants.totalProfilesPath).set(ServerValue.increment(-1));
      } catch (_) {}
    }
    await _db.child(AppConstants.profilesByOwnerPath).child(userId).remove();
    await _db.child(AppConstants.usersPath).child(userId).remove();
  }
}
