import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

import '../../../../core/services/premium_service.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/create_milestone_usecase.dart';

part 'create_milestone_state.dart';

class CreateMilestoneCubit extends Cubit<CreateMilestoneState> {
  final CreateMilestoneUseCase _createMilestone;
  final PremiumService _premium;

  CreateMilestoneCubit(
    this._createMilestone,
    this._premium,
  ) : super(const CreateMilestoneInitial());

  Future<void> submit({
    String? title,
    required String userNote,
    required DateTime eventDate,
    List<File> mediaFiles = const [],
    List<MediaType> mediaTypes = const [],
    int? savedLocationId,
    String? locationName,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    String categoryId = 'otros',
    List<String> participants = const [],
    List<String> protagonistIds = const [],
    bool isPublic = false,
  }) async {
    String? imageBase64;
    final primaryFile = mediaFiles.isNotEmpty ? mediaFiles.first : null;

    // Drive: subida diferida vía CloudSyncService (OAuth Google Sign-In con scope Drive).
    // No usar el token de sesión Supabase aquí (provoca "Expected OAuth 2 access token").

    emit(CreateMilestoneSubmitting(
      _premium.isPremium ? 'Guardando hito…' : 'Redactando historia...',
    ));

    if (primaryFile != null) {
      imageBase64 = await _encodeForVision(primaryFile);
    }
    final result = await _createMilestone(CreateMilestoneParams(
      title: title,
      userNote: userNote,
      eventDate: eventDate,
      savedLocationId: savedLocationId,
      locationName: locationName,
      locationCity: locationCity,
      locationCountry: locationCountry,
      latitude: latitude,
      longitude: longitude,
      categoryId: categoryId,
      participants: participants,
      protagonistIds: protagonistIds,
      isPublic: isPublic,
      imageBase64: imageBase64,
      localMediaPaths: mediaFiles.map((f) => f.path).toList(),
      localMediaTypes: mediaTypes,
    ));
    result.fold(
      (failure) =>
          emit(CreateMilestoneError(failure.message, code: failure.code)),
      (milestone) => emit(CreateMilestoneSuccess(milestone)),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Reads [file], resizes so the longest dimension ≤ 1024 px, re-encodes
  /// as JPEG at quality 85, and returns the Base64 string.
  ///
  /// Returns null on any error (file missing, corrupt image, OOM…) so the
  /// caller gracefully falls back to text-only biographer mode.
  static Future<String?> _encodeForVision(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      const maxDim = 1024;
      final scale = maxDim / math.max(decoded.width, decoded.height);
      final output = scale < 1.0
          ? img.copyResize(
              decoded,
              width: (decoded.width * scale).round(),
              height: (decoded.height * scale).round(),
            )
          : decoded;

      return base64Encode(img.encodeJpg(output, quality: 85));
    } catch (_) {
      // Graceful degradation: text-only biographer if image processing fails.
      return null;
    }
  }

}
