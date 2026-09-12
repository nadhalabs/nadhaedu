import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/features/academic/academic_profile.dart';

class AcademicProfileScreen extends StatelessWidget {
  const AcademicProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Academic Profile')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AcademicProfileForm(onSaved: () => context.go('/home')),
    ),
  );
}

class AcademicProfileForm extends ConsumerStatefulWidget {
  const AcademicProfileForm({
    super.key,
    required this.onSaved,
    this.saveLabel = 'Save Academic Profile',
    this.validateBeforeSave,
  });
  final FutureOr<void> Function() onSaved;
  final bool Function()? validateBeforeSave;
  final String saveLabel;
  @override
  ConsumerState<AcademicProfileForm> createState() =>
      _AcademicProfileFormState();
}

class _AcademicProfileFormState extends ConsumerState<AcademicProfileForm> {
  String? curriculum, standard, stream, error;
  bool initialized = false, saving = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(academicProfileProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError) {
      return Column(
        children: [
          const Text('Could not load your academic profile.'),
          TextButton(
            onPressed: () => ref.invalidate(academicProfileProvider),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (!initialized) {
      initialized = true;
      curriculum = state.valueOrNull?.curriculumId;
      standard = state.valueOrNull?.standardId;
      stream = state.valueOrNull?.streamId;
    }
    final curricula = ref.watch(academicOptionsProvider('curricula'));
    final standards = curriculum == null
        ? const AsyncData<List<AcademicOption>>([])
        : ref.watch(academicOptionsProvider('curricula/$curriculum/standards'));
    final streams = standard == null
        ? const AsyncData<List<AcademicOption>>([])
        : ref.watch(academicOptionsProvider('standards/$standard/streams'));
    final valid =
        curricula.valueOrNull?.any((x) => x.id == curriculum) == true &&
        standards.valueOrNull?.any((x) => x.id == standard) == true &&
        streams.hasValue &&
        ((streams.valueOrNull?.isEmpty ?? false) ||
            streams.valueOrNull!.any((x) => x.id == stream));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose what you are studying. Your progress, bookmarks and downloads stay saved when you switch.',
        ),
        const SizedBox(height: 20),
        _selector(
          'Curriculum / Board',
          curriculum,
          curricula,
          (id) => setState(() {
            curriculum = id;
            standard = null;
            stream = null;
          }),
        ),
        const SizedBox(height: 16),
        _selector(
          'Standard / Class',
          standard,
          standards,
          (id) => setState(() {
            standard = id;
            stream = null;
          }),
        ),
        if (standard != null &&
            (streams.isLoading ||
                streams.hasError ||
                (streams.valueOrNull?.isNotEmpty ?? false))) ...[
          const SizedBox(height: 16),
          _selector(
            'Stream',
            stream,
            streams,
            (id) => setState(() => stream = id),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving || !valid
              ? null
              : () async {
                  if (!(widget.validateBeforeSave?.call() ?? true)) return;
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await ref
                        .read(academicProfileProvider.notifier)
                        .save(
                          curriculum!,
                          standard!,
                          streams.valueOrNull!.isEmpty ? null : stream,
                        );
                    if (mounted) await widget.onSaved();
                  } on Object catch (failure) {
                    if (mounted) {
                      setState(
                        () =>
                            error = 'Could not save academic profile. $failure',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'Saving…' : widget.saveLabel),
        ),
      ],
    );
  }

  Widget _selector(
    String label,
    String? selected,
    AsyncValue<List<AcademicOption>> options,
    ValueChanged<String?> onChanged,
  ) => options.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) =>
        Text('Could not load $label. Reopen this screen to retry.'),
    data: (items) => DropdownButtonFormField<String>(
      key: ValueKey('$label|$selected|${items.map((x) => x.id).join()}'),
      initialValue: items.any((x) => x.id == selected) ? selected : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
          .toList(),
      onChanged: saving ? null : onChanged,
    ),
  );
}
