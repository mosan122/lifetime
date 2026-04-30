import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

import '../../../../core/failures/failure.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../domain/entities/milestone.dart';
import '../../domain/usecases/create_milestone_usecase.dart';
import '../../domain/usecases/upload_media_usecase.dart';

part 'create_milestone_state.dart';

class CreateMilestoneCubit extends Cubit<CreateMilestoneState> {
  final CreateMilestoneUseCase _createMilestone;
  final UploadMediaUseCase _uploadMedia;

  CreateMilestoneCubit(this._createMilestone, this._uploadMedia)
      : super(const CreateMilestoneInitial());

  Future<void> submit({
    String? title,
    required String userNote,
    required DateTime eventDate,
    List<File> mediaFiles = const [],
    List<MediaType> mediaTypes = const [],
    String? accessToken,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  }) async {
    String? driveFileId;
    String? imageBase64;
    final primaryFile = mediaFiles.isNotEmpty ? mediaFiles.first : null;

    // ── Step 1: Drive upload (requires auth) ──────────────────────────────────
    if (primaryFile != null && accessToken != null) {
      emit(const CreateMilestoneSubmitting('Subiendo imagen...'));
      final uploadResult = await _uploadMedia(UploadMediaParams(
        file: primaryFile,
        accessToken: accessToken,
        mimeType: _mimeFromPath(primaryFile.path),
      ));
      final failure = uploadResult.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        emit(CreateMilestoneError(failure.message, code: failure.code));
        return;
      }
      driveFileId = uploadResult.fold((_) => null, (id) => id);
    }

    // ── Step 2: Encode image for Gemini Vision ────────────────────────────────
    // Runs regardless of Drive auth: Vision and Drive are independent.
    // The image is resized to ≤1024px before encoding to keep payload small.
    if (primaryFile != null) {
      imageBase64 = await _encodeForVision(primaryFile);
    }

    // ── Step 3: Biographer narrative + DB insert ──────────────────────────────
    emit(const CreateMilestoneSubmitting());
    final result = await _createMilestone(CreateMilestoneParams(
      title: title,
      userNote: userNote,
      eventDate: eventDate,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      category: category,
      participants: participants,
      isPublic: isPublic,
      driveFileId: driveFileId,
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

  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'heic' || ext == 'heif') return 'image/heic';
    return 'image/jpeg';
  }
}
