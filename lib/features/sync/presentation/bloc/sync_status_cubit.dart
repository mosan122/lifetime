import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SyncPhase { idle, syncingMetadata, syncingMedia, error }

class SyncStatusState extends Equatable {
  const SyncStatusState({
    this.phase = SyncPhase.idle,
    this.message,
    this.errorMessage,
    this.showSuccessCheck = false,
  });

  final SyncPhase phase;
  final String? message;
  final String? errorMessage;
  final bool showSuccessCheck;

  bool get isBusy =>
      phase == SyncPhase.syncingMetadata || phase == SyncPhase.syncingMedia;

  String? get displayMessage {
    if (showSuccessCheck) return 'Sincronización completada';
    if (phase == SyncPhase.error) return errorMessage;
    return message;
  }

  SyncStatusState copyWith({
    SyncPhase? phase,
    String? message,
    String? errorMessage,
    bool clearError = false,
    bool clearMessage = false,
    bool? showSuccessCheck,
  }) {
    return SyncStatusState(
      phase: phase ?? this.phase,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showSuccessCheck: showSuccessCheck ?? this.showSuccessCheck,
    );
  }

  @override
  List<Object?> get props => [phase, message, errorMessage, showSuccessCheck];
}

/// Estado global de sincronización premium (metadatos vs medios/Drive).
class SyncStatusCubit extends Cubit<SyncStatusState> {
  SyncStatusCubit() : super(const SyncStatusState());

  Timer? _successTimer;

  void startMetadata({String? message}) {
    _successTimer?.cancel();
    emit(
      SyncStatusState(
        phase: SyncPhase.syncingMetadata,
        message: message ?? 'Sincronizando hitos, personas y lugares…',
      ),
    );
  }

  void updateMetadataMessage(String message) {
    if (state.phase != SyncPhase.syncingMetadata) return;
    emit(state.copyWith(message: message));
  }

  void startMedia({String? message}) {
    _successTimer?.cancel();
    emit(
      SyncStatusState(
        phase: SyncPhase.syncingMedia,
        message: message ?? 'Sincronizando fotos y vídeos con Google Drive…',
      ),
    );
  }

  void updateMediaMessage(String message) {
    if (state.phase != SyncPhase.syncingMedia) return;
    emit(state.copyWith(message: message));
  }

  void reportError(String message) {
    _successTimer?.cancel();
    emit(
      SyncStatusState(
        phase: SyncPhase.error,
        errorMessage: message,
        showSuccessCheck: false,
      ),
    );
  }

  void markIdleWithSuccess() {
    _successTimer?.cancel();
    emit(
      const SyncStatusState(
        phase: SyncPhase.idle,
        message: 'Sincronización completada',
        showSuccessCheck: true,
      ),
    );
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed && state.showSuccessCheck) {
        emit(const SyncStatusState());
      }
    });
  }

  void markIdle() {
    if (state.phase == SyncPhase.idle && !state.showSuccessCheck) return;
    _successTimer?.cancel();
    emit(const SyncStatusState());
  }

  @override
  Future<void> close() {
    _successTimer?.cancel();
    return super.close();
  }
}
