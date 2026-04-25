// lib/features/auth/data/backend_user_providers.dart
//
// Providers utilisateurs basés sur le backend REST (MySQL).
// Remplace la lecture de Firestore pour les profils.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../domain/user_model.dart';
import 'auth_providers.dart';

const _userCachePrefix = 'backend_user_';
const _userCacheTtl = Duration(hours: 24);

UserModel? _deserialize(dynamic raw) {
  if (raw is! Map) return null;
  return UserModel(
    alanyaID: raw['alanyaID'] as int? ?? 0,
    uid: raw['uid']?.toString() ?? '',
    name: raw['nom']?.toString() ?? '',
    pseudo: raw['pseudo']?.toString() ?? '',
    phone: raw['alanyaPhone']?.toString() ?? '',
    photoUrl: raw['avatar_url']?.toString(),
    isOnline: (raw['is_online'] as int? ?? 0) == 1,
    lastSeen: raw['last_seen'] != null
        ? DateTime.tryParse(raw['last_seen'].toString())
        : null,
    ghostMode: (raw['exclus'] as int? ?? 0) == 1,
  );
}

Map<String, dynamic> _serialize(UserModel u) => {
      'alanyaID': u.alanyaID,
      'uid': u.uid,
      'nom': u.name,
      'pseudo': u.pseudo,
      'alanyaPhone': u.phone,
      'avatar_url': u.photoUrl,
      'is_online': u.isOnline ? 1 : 0,
      'last_seen': u.lastSeen?.toIso8601String(),
      'exclus': u.ghostMode ? 1 : 0,
    };

/// Profil de l'utilisateur courant (basé sur `/api/auth-custom/me`).
/// Persisté localement pour éviter un appel à chaque redémarrage.
final currentBackendUserProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(authCustomProvider);
  if (!auth.isLoggedIn || auth.user == null) return null;

  try {
    final raw = await ApiService.instance.getMe();
    final user = UserModel.fromJson({
      ...raw,
      'uid': raw['alanyaID']?.toString() ?? '',
    });
    await LocalCache.instance.set(
      '${_userCachePrefix}me_${auth.user!.alanyaID}',
      _serialize(user),
      ttl: _userCacheTtl,
    );
    // Connecter le socket avec l'alanyaID
    await SocketService.instance.connect(user.alanyaID);
    return user;
  } catch (e) {
    debugPrint('[currentBackendUserProvider] $e');
    final entry = LocalCache.instance
        .getEntry('${_userCachePrefix}me_${auth.user!.alanyaID}');
    if (entry != null) return _deserialize(entry.data);
    return null;
  }
});

/// alanyaID (int) de l'utilisateur courant, ou null si pas prêt.
final currentAlanyaIDProvider = Provider<int?>((ref) {
  final userAsync = ref.watch(currentBackendUserProvider);
  return userAsync.value?.alanyaID;
});

/// alanyaID (String) de l'utilisateur courant — pratique pour les écrans
/// qui manipulent des IDs participant sous forme de String.
final currentAlanyaIDStringProvider = Provider<String>((ref) {
  final id = ref.watch(currentAlanyaIDProvider);
  return id?.toString() ?? '';
});

/// Récupère un utilisateur par son alanyaID (int), avec cache local.
final backendUserProvider =
    FutureProvider.family<UserModel?, int>((ref, alanyaID) async {
  if (alanyaID <= 0) return null;

  final cacheKey = '$_userCachePrefix$alanyaID';
  final cachedEntry = LocalCache.instance.getEntry(cacheKey);

  // Si cache valide → utiliser + refresh en background
  if (cachedEntry != null && !cachedEntry.isExpired) {
    // ignore: unawaited_futures
    _refreshUser(alanyaID);
    return _deserialize(cachedEntry.data);
  }

  // Sinon fetch direct
  try {
    final raw = await ApiService.instance.getUserById(alanyaID);
    final user = UserModel.fromJson(raw);
    await LocalCache.instance
        .set(cacheKey, _serialize(user), ttl: _userCacheTtl);
    return user;
  } catch (e) {
    if (cachedEntry != null) return _deserialize(cachedEntry.data);
    return null;
  }
});

/// Version acceptant un ID String (pour compat avec code existant qui
/// manipule les IDs participant sous forme de String).
final backendUserByStringIDProvider =
    FutureProvider.family<UserModel?, String>((ref, stringID) async {
  final id = int.tryParse(stringID);
  if (id == null || id <= 0) return null;
  return ref.watch(backendUserProvider(id).future);
});

/// Stream d'un utilisateur par alanyaID : émet l'utilisateur depuis REST,
/// puis met à jour `isOnline` en écoutant les events `presence:updated`.
final backendUserStreamProvider =
    StreamProvider.family<UserModel?, int>((ref, alanyaID) async* {
  if (alanyaID <= 0) {
    yield null;
    return;
  }

  UserModel? current = await ref.watch(backendUserProvider(alanyaID).future);
  yield current;

  final socket = ref.watch(
    Provider((_) => SocketService.instance),
  );

  await for (final event in socket.onPresence) {
    if (event.userID != alanyaID) continue;
    if (current != null) {
      current = current.copyWith(
        isOnline: event.online,
        lastSeen: event.online ? current.lastSeen : DateTime.now(),
      );
      yield current;
    }
  }
});

Future<void> _refreshUser(int alanyaID) async {
  try {
    final raw = await ApiService.instance.getUserById(alanyaID);
    final user = UserModel.fromJson(raw);
    await LocalCache.instance.set(
      '$_userCachePrefix$alanyaID',
      _serialize(user),
      ttl: _userCacheTtl,
    );
  } catch (_) {
    // best effort
  }
}

/// Prefetch cache pour une liste d'alanyaID.
final prefetchBackendUsersProvider =
    FutureProvider.family<void, List<int>>((ref, ids) async {
  final toFetch = <int>[];
  for (final id in ids) {
    if (id <= 0) continue;
    final entry = LocalCache.instance.getEntry('$_userCachePrefix$id');
    if (entry == null || entry.isExpired) toFetch.add(id);
  }
  if (toFetch.isEmpty) return;

  await Future.wait(toFetch.map((id) async {
    try {
      final raw = await ApiService.instance.getUserById(id);
      final user = UserModel.fromJson(raw);
      await LocalCache.instance.set(
        '$_userCachePrefix$id',
        _serialize(user),
        ttl: _userCacheTtl,
      );
    } catch (_) {
      // skip
    }
  }));
});
