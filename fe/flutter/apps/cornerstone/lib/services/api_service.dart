import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class CornerstoneApiClient {
  CornerstoneApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String baseUrl;

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment(
      'CORNERSTONE_API_BASE_URL',
      defaultValue: '',
    );
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    final runtimeBase = Uri.base;
    if (runtimeBase.scheme == 'http' || runtimeBase.scheme == 'https') {
      return runtimeBase.origin;
    }

    return 'http://localhost';
  }

  Future<DashboardPayload> fetchDashboard() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/dashboard'));
    return DashboardPayload.fromJson(_decode(response));
  }

  Future<ViewerSessionPayload> fetchViewerSession() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/session'));
    return ViewerSessionPayload.fromJson(_decode(response));
  }

  Uri googleStartUri({String nextPath = '/'}) {
    return Uri.parse(
      '$baseUrl/api/v1/auth/google/start',
    ).replace(queryParameters: {'next': nextPath});
  }

  Future<void> logout() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/signout'),
    );
    _decode(response);
  }

  Future<ViewerSessionPayload> switchActiveUser(String userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/session/active-user'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    return ViewerSessionPayload.fromJson(_decode(response));
  }

  Future<ViewerSessionPayload> switchActiveTeam(String teamId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/session/active-team'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': teamId}),
    );
    return ViewerSessionPayload.fromJson(_decode(response));
  }

  Future<LibraryPayload> fetchLibrary() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/library'));
    return LibraryPayload.fromJson(_decode(response));
  }

  Future<LibraryWorkspacePayload> fetchLibraryWorkspace() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/library/workspace'),
    );
    return LibraryWorkspacePayload.fromJson(_decode(response));
  }

  Future<LibraryDocumentsPayload> fetchLibraryDocuments() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/library/documents'),
    );
    return LibraryDocumentsPayload.fromJson(_decode(response));
  }

  Future<LibraryDocumentData> fetchLibraryDocument(String routePath) async {
    final response = await _client.get(
      Uri.parse(
        '$baseUrl/api/v1/library/document',
      ).replace(queryParameters: {'route_path': routePath}),
    );
    return LibraryDocumentPayload.fromJson(_decode(response)).document;
  }

  Future<LearnerDetailPayload> fetchLearnerDetail(String learnerId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/learners/$learnerId'),
    );
    return LearnerDetailPayload.fromJson(_decode(response));
  }

  Future<LearnerWorkspacePayload> fetchLearnerWorkspace(
    String learnerId,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/learners/$learnerId/workspace'),
    );
    return LearnerWorkspacePayload.fromJson(_decode(response));
  }

  Future<void> createAssignment({
    required String learnerId,
    required String playlistId,
    String? startDate,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/assignments'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'learner_id': learnerId,
        'playlist_id': playlistId,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
      }),
    );
    _decode(response);
  }

  Future<void> recordSession({
    required String sessionId,
    required double score,
    required double maxScore,
    required int durationMinutes,
    required String notes,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/sessions/$sessionId/record'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'score': score,
        'max_score': maxScore,
        'duration_minutes': durationMinutes,
        'notes': notes,
      }),
    );
    _decode(response);
  }

  Future<ActivityInstance> startSessionMaterialActivity({
    required String sessionId,
    required String sessionMaterialId,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '$baseUrl/api/v1/sessions/$sessionId/materials/$sessionMaterialId/start',
      ),
    );
    return ActivityStartPayload.fromJson(_decode(response)).activity;
  }

  Future<CompleteActivityResponse> completeActivity({
    required String activityInstanceId,
    required List<String> answers,
    required List<ActivityItem> items,
    required int durationSeconds,
    required String notes,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '$baseUrl/api/v1/activity-instances/$activityInstanceId/complete',
      ),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'responses': List.generate(
          items.length,
          (index) => {'item_id': items[index].itemId, 'value': answers[index]},
        ),
        'duration_seconds': durationSeconds,
        'notes': notes,
      }),
    );
    return CompleteActivityResponse.fromJson(_decode(response));
  }

  Future<ActivityInstance> retryActivity(String activityInstanceId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/activity-instances/$activityInstanceId/retry'),
    );
    return ActivityStartPayload.fromJson(_decode(response)).activity;
  }

  Future<ActivityInstance> startReviewItem(String reviewItemId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/review-items/$reviewItemId/start'),
    );
    return ActivityStartPayload.fromJson(_decode(response)).activity;
  }

  Future<void> setReadinessOverride({
    required String learnerId,
    required String materialId,
    required int minimumRuns,
    required int recentRunWindow,
    required double targetAccuracy,
    required int consecutiveTargetRunsRequired,
    int? targetCorrectCount,
    required int minimumDistinctItems,
    required int minimumFamilyCount,
    int? maxDurationSeconds,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/learners/$learnerId/readiness-overrides'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'material_id': materialId,
        'minimum_runs': minimumRuns,
        'recent_run_window': recentRunWindow,
        'target_accuracy': targetAccuracy,
        'consecutive_target_runs': consecutiveTargetRunsRequired,
        'target_correct_count': ?targetCorrectCount,
        'minimum_distinct_items': minimumDistinctItems,
        'minimum_family_count': minimumFamilyCount,
        'max_duration_seconds': ?maxDurationSeconds,
        'reason': reason,
      }),
    );
    _decode(response);
  }

  Future<void> clearReadinessOverride({
    required String learnerId,
    required String materialId,
  }) async {
    final response = await _client.delete(
      Uri.parse(
        '$baseUrl/api/v1/learners/$learnerId/readiness-overrides/$materialId',
      ),
    );
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(decoded['message'] ?? 'Request failed');
    }
    return decoded;
  }
}
