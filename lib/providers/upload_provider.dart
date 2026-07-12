import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ── Upload state ──────────────────────────────────────────────────────────────
enum UploadStatus { idle, uploading, success, error }
enum StudyMode   { fixedPeriod, untilMastery }

class UploadState {
  final UploadStatus status;
  final String?  fileName;
  final double   progress;
  final String?  error;
  final StudyMode studyMode;
  final int?     learningDays;
  final bool     starting;

  // Populated once /upload succeeds — this is what the quiz screen needs.
  final String?  sessionId;
  final int?     totalChunks;
  final Map<String, dynamic>? difficultySummary;

  const UploadState({
    this.status    = UploadStatus.idle,
    this.fileName,
    this.progress  = 0,
    this.error,
    this.studyMode = StudyMode.fixedPeriod,
    this.learningDays,
    this.starting  = false,
    this.sessionId,
    this.totalChunks,
    this.difficultySummary,
  });

  UploadState copyWith({
    UploadStatus? status, String? fileName, double? progress,
    String? error, StudyMode? studyMode, int? learningDays, bool? starting,
    String? sessionId, int? totalChunks, Map<String, dynamic>? difficultySummary,
    bool clearError = false,
  }) => UploadState(
    status:             status             ?? this.status,
    fileName:           fileName           ?? this.fileName,
    progress:           progress           ?? this.progress,
    error:              clearError ? null : (error ?? this.error),
    studyMode:          studyMode          ?? this.studyMode,
    learningDays:       learningDays       ?? this.learningDays,
    starting:           starting           ?? this.starting,
    sessionId:          sessionId          ?? this.sessionId,
    totalChunks:        totalChunks        ?? this.totalChunks,
    difficultySummary:  difficultySummary  ?? this.difficultySummary,
  );
}

// ── UploadProvider (ChangeNotifier) ───────────────────────────────────────────
// Talks to POST /upload on the Flask backend (see /backend/app.py). The
// backend runs Model 1 (difficulty prediction) on the PDF and returns a
// session_id that the quiz screen (learning_session_screen.dart) then uses
// to fetch adaptive questions via /session/<id>/start.
class UploadProvider extends ChangeNotifier {
  UploadState _state = const UploadState();
  UploadState get state => _state;

  /// Uploads the picked file's raw bytes to the backend.
  /// [sizeMB] is only used for the client-side size check.
  Future<void> processFile(String name, Uint8List bytes, double sizeMB) async {
    if (sizeMB > 60) {
      _state = _state.copyWith(status: UploadStatus.error, error: 'File exceeds 60 MB limit.');
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
      final uri = Uri.parse('$kApiBaseUrl/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['study_days'] = (_state.learningDays ?? 7).toString()
        ..fields['mode'] = _state.studyMode == StudyMode.untilMastery
            ? 'until_mastery'
            : 'fixed'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));

      _state = _state.copyWith(progress: 0.55);
      notifyListeners();

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        final body = _tryDecode(response.body);
        throw Exception(body?['error'] ?? 'Upload failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _state = _state.copyWith(
        status: UploadStatus.success,
        progress: 1.0,
        sessionId: data['session_id'] as String?,
        totalChunks: data['total_chunks'] as int?,
        difficultySummary: data['difficulty_summary'] as Map<String, dynamic>?,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: UploadStatus.error,
        error: 'Could not reach the AI backend. Is it running on $kApiBaseUrl? ($e)',
      );
      notifyListeners();
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void setMode(StudyMode m) {
    _state = _state.copyWith(studyMode: m);
    notifyListeners();
  }

  void setDays(int d) {
    _state = _state.copyWith(learningDays: d);
    notifyListeners();
  }

  /// Brief transition before navigating to the quiz screen. The quiz screen
  /// itself calls POST /session/<id>/start to fetch adaptive questions, so
  /// this just needs to confirm we have a session_id ready.
  Future<void> startLearning() async {
    if (_state.sessionId == null) return;
    _state = _state.copyWith(starting: true);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _state = _state.copyWith(starting: false);
    notifyListeners();
  }

  void reset() {
    _state = const UploadState();
    notifyListeners();
  }
}