import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

enum UploadStatus { idle, uploading, success, error }
enum StudyMode { fixedPeriod, untilMastery }

class UploadState {
  final UploadStatus status;
  final String? fileName;
  final double progress;
  final String? error;
  final StudyMode studyMode;
  final int? learningDays;
  final bool starting;
  final String? materialId;
  final int? totalChunks;
  final Map<String, dynamic>? difficultySummary;

  const UploadState({
    this.status = UploadStatus.idle,
    this.fileName,
    this.progress = 0,
    this.error,
    this.studyMode = StudyMode.fixedPeriod,
    this.learningDays,
    this.starting = false,
    this.materialId,
    this.totalChunks,
    this.difficultySummary,
  });

  UploadState copyWith({
    UploadStatus? status,
    String? fileName,
    double? progress,
    String? error,
    StudyMode? studyMode,
    int? learningDays,
    bool? starting,
    String? materialId,
    int? totalChunks,
    Map<String, dynamic>? difficultySummary,
    bool clearError = false,
  }) {
    return UploadState(
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      studyMode: studyMode ?? this.studyMode,
      learningDays: learningDays ?? this.learningDays,
      starting: starting ?? this.starting,
      materialId: materialId ?? this.materialId,
      totalChunks: totalChunks ?? this.totalChunks,
      difficultySummary: difficultySummary ?? this.difficultySummary,
    );
  }
}

class UploadProvider extends ChangeNotifier {
  UploadState _state = const UploadState();
  UploadState get state => _state;

  Future<void> processFile(String name, Uint8List bytes, double sizeMB) async {
    if (!name.toLowerCase().endsWith('.pdf')) {
      _state = _state.copyWith(
        status: UploadStatus.error,
        error: 'The current AI backend supports PDF files only.',
      );
      notifyListeners();
      return;
    }
    if (sizeMB > 60) {
      _state = _state.copyWith(
        status: UploadStatus.error,
        error: 'File exceeds the 60 MB limit.',
      );
      notifyListeners();
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _state = _state.copyWith(
        status: UploadStatus.error,
        error: 'Please sign in before uploading study material.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: UploadStatus.uploading,
      fileName: name,
      progress: 0.15,
      clearError: true,
    );
    notifyListeners();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kApiBaseUrl/upload'),
      )
        ..fields['user_id'] = userId
        ..fields['study_days'] = (_state.learningDays ?? 7).toString()
        ..fields['mode'] = _state.studyMode == StudyMode.untilMastery
            ? 'until_mastery'
            : 'fixed'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));

      _state = _state.copyWith(progress: 0.55);
      notifyListeners();

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final body = _tryDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body?['error'] ?? 'Upload failed (${response.statusCode}).');
      }

      final materialId = body?['material_id']?.toString();
      if (materialId == null || materialId.isEmpty) {
        throw Exception('The backend did not return a material_id.');
      }

      _state = _state.copyWith(
        status: UploadStatus.success,
        progress: 1,
        materialId: materialId,
        totalChunks: (body?['total_chunks'] as num?)?.toInt(),
        difficultySummary:
            (body?['difficulty_summary'] as Map?)?.cast<String, dynamic>(),
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: UploadStatus.error,
        error:
            'Could not process the PDF. Confirm that the Flask backend is running at $kApiBaseUrl. ($error)',
      );
      notifyListeners();
    }
  }

  Future<void> startLearning() async {
    if (_state.materialId == null) return;
    _state = _state.copyWith(starting: true);
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _state = _state.copyWith(starting: false);
    notifyListeners();
  }

  void setMode(StudyMode mode) {
    _state = _state.copyWith(studyMode: mode);
    notifyListeners();
  }

  void setDays(int days) {
    _state = _state.copyWith(learningDays: days);
    notifyListeners();
  }

  void reset() {
    _state = const UploadState();
    notifyListeners();
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return (jsonDecode(body) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
