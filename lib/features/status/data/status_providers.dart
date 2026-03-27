// lib/features/status/data/status_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../domain/status_model.dart';
import 'status_service.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';

final statusServiceProvider = Provider<StatusService>((ref) => StatusService());

// Stream de tous les statuts groupés par utilisateur
final statusGroupsProvider = StreamProvider<List<UserStatusGroup>>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserId = authState.value?.uid ?? '';
  if (currentUserId.isEmpty) return const Stream.empty();

  final statusService = ref.read(statusServiceProvider);
  final statusesStream = statusService.statusesStream();
  final contactsStream = ref.watch(contactsProvider.stream);

  final controller = StreamController<List<UserStatusGroup>>();
  List<StatusModel> latestStatuses = statusService.getCachedStatuses();
  Set<String> contactIds = {};

  void emit() {
    final filtered = latestStatuses.where((s) {
      return s.userId == currentUserId || contactIds.contains(s.userId);
    }).toList();
    controller.add(statusService.groupByUser(filtered, currentUserId));
  }

  // Emit cached data immediately
  emit();

  final sub1 = statusesStream.listen(
    (statuses) {
      latestStatuses = statuses;
      // cache new snapshot
      // ignore: unawaited_futures
      statusService.cacheStatuses(statuses);
      emit();
    },
    onError: controller.addError,
  );

  final sub2 = contactsStream.listen(
    (contacts) {
      contactIds = contacts.map((c) => c.id).toSet();
      emit();
    },
    onError: controller.addError,
  );

  ref.onDispose(() async {
    await sub1.cancel();
    await sub2.cancel();
    await controller.close();
  });

  return controller.stream;
});

// Mes propres statuts
final myStatusesProvider = StreamProvider<List<StatusModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(statusServiceProvider).myStatusesStream(uid);
});
