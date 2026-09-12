import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_user.dart';

@immutable
final class CmsUsersState {
  const CmsUsersState({
    this.isLoading = false,
    this.users = const [],
    this.selectedRole = 'all',
    this.searchQuery = '',
    this.errorMessage,
  });

  final bool isLoading;
  final List<CmsUserSummary> users;
  final String selectedRole;
  final String searchQuery;
  final String? errorMessage;

  List<CmsUserSummary> get filteredUsers {
    var list = users;
    if (selectedRole != 'all') {
      list = list.where((u) => u.role.value == selectedRole).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where(
            (u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  CmsUsersState copyWith({
    bool? isLoading,
    List<CmsUserSummary>? users,
    String? selectedRole,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) => CmsUsersState(
    isLoading: isLoading ?? this.isLoading,
    users: users ?? this.users,
    selectedRole: selectedRole ?? this.selectedRole,
    searchQuery: searchQuery ?? this.searchQuery,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final class CmsUsersController extends StateNotifier<CmsUsersState> {
  CmsUsersController({required CmsRepository repository})
    : _repository = repository,
      super(const CmsUsersState(isLoading: true)) {
    unawaited(load());
  }

  final CmsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getUsers(pageSize: 100);
    state = switch (result) {
      Success(value: final items) => state.copyWith(
        isLoading: false,
        users: items,
        clearError: true,
      ),
      Failure(failure: final failure) => state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    };
  }

  void setRole(String role) {
    state = state.copyWith(selectedRole: role);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}
