import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection_container.dart';
import '../bloc/create_milestone_cubit.dart';

class AddMilestonePage extends StatelessWidget {
  const AddMilestonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreateMilestoneCubit>(),
      child: const _AddMilestoneView(),
    );
  }
}

class _AddMilestoneView extends StatefulWidget {
  const _AddMilestoneView();

  @override
  State<_AddMilestoneView> createState() => _AddMilestoneViewState();
}

class _AddMilestoneViewState extends State<_AddMilestoneView> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;
    context.read<CreateMilestoneCubit>().submit(
          userNote: note,
          eventDate: DateTime.now(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CreateMilestoneCubit, CreateMilestoneState>(
      listener: (context, state) {
        if (state is CreateMilestoneSuccess) {
          Navigator.pop(context, true);
        }
        if (state is CreateMilestoneError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is CreateMilestoneSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nuevo Hito'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Qué momento quieres recordar?',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe con tus palabras. La IA lo convertirá en un recuerdo.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      maxLines: null,
                      expands: true,
                      autofocus: true,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Hoy celebré...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFAAAAAA),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAE8),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppTheme.navy, width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _noteController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.navy.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              isSubmitting || !hasText ? null : () => _submit(context),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Guardar',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
