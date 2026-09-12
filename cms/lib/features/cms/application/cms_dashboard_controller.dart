import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/domain/cms_dashboard_data.dart';

@immutable
final class CmsDashboardState {
  const CmsDashboardState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.data,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isRefreshing;
  final CmsDashboardData? data;
  final String? errorMessage;

  CmsDashboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    CmsDashboardData? data,
    String? errorMessage,
    bool clearError = false,
  }) => CmsDashboardState(
    isLoading: isLoading ?? this.isLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    data: data ?? this.data,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final class CmsDashboardController extends StateNotifier<CmsDashboardState> {
  CmsDashboardController({required CmsRepository repository})
    : _repository = repository,
      super(const CmsDashboardState(isLoading: true)) {
    unawaited(load());
  }

  final CmsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getDashboardData();
    state = switch (result) {
      Success(value: final data) => state.copyWith(
        isLoading: false,
        data: data,
        clearError: true,
      ),
      Failure(failure: final failure) => state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    };
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _repository.getDashboardData();
    state = switch (result) {
      Success(value: final data) => state.copyWith(
        isRefreshing: false,
        data: data,
        clearError: true,
      ),
      Failure(failure: final failure) => state.copyWith(
        isRefreshing: false,
        errorMessage: failure.message,
      ),
    };
  }
}
