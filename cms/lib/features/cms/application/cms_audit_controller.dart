import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_audit_log.dart';

@immutable
final class CmsAuditState {
  const CmsAuditState({
    this.isLoading = false,
    this.logs = const [],
    this.selectedEventType = 'all',
    this.searchQuery = '',
    this.errorMessage,
  });

  final bool isLoading;
  final List<CmsAuditLogItem> logs;
  final String selectedEventType;
  final String searchQuery;
  final String? errorMessage;

  List<CmsAuditLogItem> get filteredLogs {
    var list = logs;
    if (selectedEventType != 'all') {
      list = list.where((a) => a.action.contains(selectedEventType)).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where(
            (a) =>
                a.action.toLowerCase().contains(q) ||
                (a.actorEmail?.toLowerCase().contains(q) ?? false) ||
                (a.actorName?.toLowerCase().contains(q) ?? false) ||
                a.targetId.toLowerCase().contains(q) ||
                (a.reason?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  CmsAuditState copyWith({
    bool? isLoading,
    List<CmsAuditLogItem>? logs,
    String? selectedEventType,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) => CmsAuditState(
    isLoading: isLoading ?? this.isLoading,
    logs: logs ?? this.logs,
    selectedEventType: selectedEventType ?? this.selectedEventType,
    searchQuery: searchQuery ?? this.searchQuery,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final class CmsAuditController extends StateNotifier<CmsAuditState> {
  CmsAuditController({required CmsRepository repository})
    : _repository = repository,
      super(const CmsAuditState(isLoading: true)) {
    unawaited(load());
  }

  final CmsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getAuditLogs(pageSize: 100);
    state = switch (result) {
      Success(value: final items) => state.copyWith(
        isLoading: false,
        logs: items,
        clearError: true,
      ),
      Failure(failure: final failure) => state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    };
  }

  void setEventType(String eventType) {
    state = state.copyWith(selectedEventType: eventType);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}
