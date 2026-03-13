// lib/features/status/data/status_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/status_model.dart';
import 'status_service.dart';
import '../../auth/data/auth_providers.dart';

final statusServiceProvider = Provider<StatusService>((ref) => StatusService());

// Stream de tous les statuts groupés par utilisateur
final statusGroupsProvider = StreamProvider<List<UserStatusGroup>>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserId = authState.value?.uid ?? '';

  return ref.read(statusServiceProvider)
      .statusesStream()
      .map((statuses) => ref
          .read(statusServiceProvider)
          .groupByUser(statuses, currentUserId));
});

// Mes propres statuts
final myStatusesProvider = StreamProvider<List<StatusModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(statusServiceProvider).myStatusesStream(uid);
});