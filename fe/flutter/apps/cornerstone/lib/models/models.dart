class DashboardPayload {
  DashboardPayload({required this.learners, this.team, this.library});

  factory DashboardPayload.fromJson(Map<String, dynamic> json) {
    return DashboardPayload(
      team: json['team'] == null
          ? null
          : TeamInfo.fromJson(json['team'] as Map<String, dynamic>),
      library: json['library'] == null
          ? null
          : LibraryReport.fromJson(json['library'] as Map<String, dynamic>),
      learners: (json['learners'] as List<dynamic>)
          .map(
            (item) => LearnerDashboard.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final TeamInfo? team;
  final LibraryReport? library;
  final List<LearnerDashboard> learners;
}

class ViewerSessionPayload {
  ViewerSessionPayload({
    required this.status,
    required this.authenticated,
    required this.auth,
    required this.availableTeams,
    required this.availableUsers,
    this.team,
    this.authenticatedUser,
    this.activeUser,
    this.developerDocsUrl,
  });

  factory ViewerSessionPayload.fromJson(Map<String, dynamic> json) {
    return ViewerSessionPayload(
      status: json['status'] as String,
      authenticated: json['authenticated'] as bool? ?? false,
      auth: AuthOptions.fromJson(
        (json['auth'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      team: json['team'] == null
          ? null
          : TeamInfo.fromJson(json['team'] as Map<String, dynamic>),
      availableTeams:
          ((json['available_teams'] as List<dynamic>?) ?? const <dynamic>[])
              .map((item) => TeamInfo.fromJson(item as Map<String, dynamic>))
              .toList(),
      authenticatedUser: json['authenticated_user'] == null
          ? null
          : ViewerUser.fromJson(
              json['authenticated_user'] as Map<String, dynamic>,
            ),
      activeUser: json['active_user'] == null
          ? null
          : ViewerUser.fromJson(json['active_user'] as Map<String, dynamic>),
      developerDocsUrl: json['developer_docs_url'] as String?,
      availableUsers:
          ((json['available_users'] as List<dynamic>?) ?? const <dynamic>[])
              .map((item) => ViewerUser.fromJson(item as Map<String, dynamic>))
              .toList(),
    );
  }

  final String status;
  final bool authenticated;
  final AuthOptions auth;
  final TeamInfo? team;
  final List<TeamInfo> availableTeams;
  final ViewerUser? authenticatedUser;
  final ViewerUser? activeUser;
  final String? developerDocsUrl;
  final List<ViewerUser> availableUsers;
}

class AuthOptions {
  AuthOptions({required this.googleSignin});

  factory AuthOptions.fromJson(Map<String, dynamic> json) {
    return AuthOptions(googleSignin: json['google_signin'] as bool? ?? false);
  }

  final bool googleSignin;
}

class LibraryPayload {
  LibraryPayload({required this.report, required this.bundle});

  factory LibraryPayload.fromJson(Map<String, dynamic> json) {
    return LibraryPayload(
      report: LibraryReport.fromJson(json['report'] as Map<String, dynamic>),
      bundle: LibraryBundle.fromJson(json['bundle'] as Map<String, dynamic>),
    );
  }

  final LibraryReport report;
  final LibraryBundle bundle;
}

class LibraryWorkspacePayload {
  LibraryWorkspacePayload({
    required this.status,
    required this.pathways,
    this.featuredRoutePath,
  });

  factory LibraryWorkspacePayload.fromJson(Map<String, dynamic> json) {
    return LibraryWorkspacePayload(
      status: json['status'] as String,
      featuredRoutePath: json['featured_route_path'] as String?,
      pathways: (json['pathways'] as List<dynamic>)
          .map(
            (item) =>
                LibraryWorkspacePathway.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String status;
  final String? featuredRoutePath;
  final List<LibraryWorkspacePathway> pathways;
}

class LibraryWorkspacePathway {
  LibraryWorkspacePathway({
    required this.pathwayId,
    required this.title,
    required this.description,
    required this.areaTitle,
    required this.recommendedAgeMin,
    required this.recommendedAgeMax,
    required this.stageCount,
    required this.playlistCount,
    required this.entryPoints,
    required this.playlists,
    this.routePath,
  });

  factory LibraryWorkspacePathway.fromJson(Map<String, dynamic> json) {
    return LibraryWorkspacePathway(
      pathwayId: json['pathway_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      areaTitle: json['area_title'] as String,
      recommendedAgeMin: (json['recommended_age_min'] as num).toInt(),
      recommendedAgeMax: (json['recommended_age_max'] as num).toInt(),
      stageCount: (json['stage_count'] as num).toInt(),
      playlistCount: (json['playlist_count'] as num).toInt(),
      routePath: json['route_path'] as String?,
      entryPoints: (json['entry_points'] as List<dynamic>)
          .map(
            (item) => PathwayEntryPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      playlists: (json['playlists'] as List<dynamic>)
          .map(
            (item) =>
                LibraryWorkspacePlaylist.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String pathwayId;
  final String title;
  final String description;
  final String areaTitle;
  final int recommendedAgeMin;
  final int recommendedAgeMax;
  final int stageCount;
  final int playlistCount;
  final String? routePath;
  final List<PathwayEntryPoint> entryPoints;
  final List<LibraryWorkspacePlaylist> playlists;
}

class PathwayEntryPoint {
  PathwayEntryPoint({
    required this.age,
    required this.playlistId,
    required this.playlistTitle,
  });

  factory PathwayEntryPoint.fromJson(Map<String, dynamic> json) {
    return PathwayEntryPoint(
      age: (json['age'] as num).toInt(),
      playlistId: json['playlist_id'] as String,
      playlistTitle: json['playlist_title'] as String,
    );
  }

  final int age;
  final String playlistId;
  final String playlistTitle;
}

class LibraryWorkspacePlaylist {
  LibraryWorkspacePlaylist({
    required this.playlistId,
    required this.title,
    required this.description,
    required this.recommendedAge,
    required this.recommendedLevel,
    required this.durationDays,
    required this.stageCount,
    required this.skillCount,
    required this.materialCount,
    required this.liveMaterialCount,
    required this.deliveryShape,
    required this.assignmentTargets,
    required this.sessions,
    this.routePath,
  });

  factory LibraryWorkspacePlaylist.fromJson(Map<String, dynamic> json) {
    return LibraryWorkspacePlaylist(
      playlistId: json['playlist_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      recommendedAge: (json['recommended_age'] as num).toInt(),
      recommendedLevel: json['recommended_level'] as String,
      durationDays: (json['duration_days'] as num).toInt(),
      stageCount: (json['stage_count'] as num).toInt(),
      skillCount: (json['skill_count'] as num).toInt(),
      materialCount: (json['material_count'] as num).toInt(),
      liveMaterialCount: (json['live_material_count'] as num).toInt(),
      deliveryShape: PlaylistDeliveryShape.fromJson(
        json['delivery_shape'] as Map<String, dynamic>,
      ),
      assignmentTargets: (json['assignment_targets'] as List<dynamic>)
          .map(
            (item) =>
                PlaylistAssignmentTarget.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      routePath: json['route_path'] as String?,
      sessions: (json['sessions'] as List<dynamic>)
          .map(
            (item) =>
                LibraryWorkspaceSession.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String playlistId;
  final String title;
  final String description;
  final int recommendedAge;
  final String recommendedLevel;
  final int durationDays;
  final int stageCount;
  final int skillCount;
  final int materialCount;
  final int liveMaterialCount;
  final PlaylistDeliveryShape deliveryShape;
  final List<PlaylistAssignmentTarget> assignmentTargets;
  final String? routePath;
  final List<LibraryWorkspaceSession> sessions;
}

class PlaylistDeliveryShape {
  PlaylistDeliveryShape({
    required this.estimatedTotalMinutes,
    required this.lessonNoteCount,
    required this.teachingNoteCount,
    required this.worksheetCount,
    required this.drillCount,
    required this.quickCheckCount,
    required this.requiresAdultSupport,
  });

  factory PlaylistDeliveryShape.fromJson(Map<String, dynamic> json) {
    return PlaylistDeliveryShape(
      estimatedTotalMinutes: (json['estimated_total_minutes'] as num).toInt(),
      lessonNoteCount: (json['lesson_note_count'] as num).toInt(),
      teachingNoteCount: (json['teaching_note_count'] as num).toInt(),
      worksheetCount: (json['worksheet_count'] as num).toInt(),
      drillCount: (json['drill_count'] as num).toInt(),
      quickCheckCount: (json['quick_check_count'] as num).toInt(),
      requiresAdultSupport: json['requires_adult_support'] as bool? ?? false,
    );
  }

  final int estimatedTotalMinutes;
  final int lessonNoteCount;
  final int teachingNoteCount;
  final int worksheetCount;
  final int drillCount;
  final int quickCheckCount;
  final bool requiresAdultSupport;
}

class PlaylistAssignmentTarget {
  PlaylistAssignmentTarget({
    required this.learnerId,
    required this.displayName,
    required this.currentAge,
    required this.currentLevel,
    required this.recommended,
    required this.statusLabel,
    required this.assignedHere,
    required this.assignedAssignmentTitles,
    this.activeAssignmentTitle,
  });

  factory PlaylistAssignmentTarget.fromJson(Map<String, dynamic> json) {
    return PlaylistAssignmentTarget(
      learnerId: json['learner_id'] as String,
      displayName: json['display_name'] as String,
      currentAge: (json['current_age'] as num).toInt(),
      currentLevel: json['current_level'] as String,
      recommended: json['recommended'] as bool? ?? false,
      statusLabel: json['status_label'] as String,
      assignedHere: json['assigned_here'] as bool? ?? false,
      activeAssignmentTitle: json['active_assignment_title'] as String?,
      assignedAssignmentTitles:
          ((json['assigned_assignment_titles'] as List<dynamic>?) ??
                  const <dynamic>[])
              .map((item) => item as String)
              .toList(),
    );
  }

  final String learnerId;
  final String displayName;
  final int currentAge;
  final String currentLevel;
  final bool recommended;
  final String statusLabel;
  final bool assignedHere;
  final String? activeAssignmentTitle;
  final List<String> assignedAssignmentTitles;
}

class LibraryWorkspaceSession {
  LibraryWorkspaceSession({
    required this.sessionIndex,
    required this.dayOffset,
    required this.title,
    required this.skillIds,
    required this.dominantKind,
    required this.requiresAdultSupport,
    required this.materialCount,
    required this.estimatedMinutes,
    required this.liveMaterialCount,
    required this.materialsByKind,
    required this.materials,
  });

  factory LibraryWorkspaceSession.fromJson(Map<String, dynamic> json) {
    return LibraryWorkspaceSession(
      sessionIndex: (json['session_index'] as num).toInt(),
      dayOffset: (json['day_offset'] as num).toInt(),
      title: json['title'] as String,
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      dominantKind: json['dominant_kind'] as String,
      requiresAdultSupport: json['requires_adult_support'] as bool? ?? false,
      materialCount: (json['material_count'] as num).toInt(),
      estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
      liveMaterialCount: (json['live_material_count'] as num).toInt(),
      materialsByKind: (json['materials_by_kind'] as List<dynamic>)
          .map(
            (item) => WorkspaceMaterialKindGroup.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      materials: (json['materials'] as List<dynamic>)
          .map(
            (item) =>
                LibraryWorkspaceMaterial.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final int sessionIndex;
  final int dayOffset;
  final String title;
  final List<String> skillIds;
  final String dominantKind;
  final bool requiresAdultSupport;
  final int materialCount;
  final int estimatedMinutes;
  final int liveMaterialCount;
  final List<WorkspaceMaterialKindGroup> materialsByKind;
  final List<LibraryWorkspaceMaterial> materials;
}

class LibraryWorkspaceMaterial {
  LibraryWorkspaceMaterial({
    required this.materialId,
    required this.title,
    required this.kind,
    required this.audience,
    required this.estimatedMinutes,
    required this.skillIds,
    required this.executable,
    this.routePath,
  });

  factory LibraryWorkspaceMaterial.fromJson(Map<String, dynamic> json) {
    return LibraryWorkspaceMaterial(
      materialId: json['material_id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String,
      audience: json['audience'] as String,
      estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      executable: json['executable'] as bool? ?? false,
      routePath: json['route_path'] as String?,
    );
  }

  final String materialId;
  final String title;
  final String kind;
  final String audience;
  final int estimatedMinutes;
  final List<String> skillIds;
  final bool executable;
  final String? routePath;

  bool get isAdultFacing => audience == 'adult';
  bool get isLearnerFacing => audience == 'learner';
}

class WorkspaceMaterialKindGroup {
  WorkspaceMaterialKindGroup({
    required this.kind,
    required this.audience,
    required this.materialCount,
    required this.materials,
  });

  factory WorkspaceMaterialKindGroup.fromJson(Map<String, dynamic> json) {
    return WorkspaceMaterialKindGroup(
      kind: json['kind'] as String,
      audience: json['audience'] as String,
      materialCount: (json['material_count'] as num).toInt(),
      materials: (json['materials'] as List<dynamic>)
          .map(
            (item) =>
                LibraryWorkspaceMaterial.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String kind;
  final String audience;
  final int materialCount;
  final List<LibraryWorkspaceMaterial> materials;
}

class LibraryDocumentsPayload {
  LibraryDocumentsPayload({required this.status, required this.documents});

  factory LibraryDocumentsPayload.fromJson(Map<String, dynamic> json) {
    return LibraryDocumentsPayload(
      status: json['status'] as String,
      documents: (json['documents'] as List<dynamic>)
          .map(
            (item) =>
                LibraryDocumentSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String status;
  final List<LibraryDocumentSummary> documents;
}

class LibraryDocumentPayload {
  LibraryDocumentPayload({required this.status, required this.document});

  factory LibraryDocumentPayload.fromJson(Map<String, dynamic> json) {
    return LibraryDocumentPayload(
      status: json['status'] as String,
      document: LibraryDocumentData.fromJson(
        json['document'] as Map<String, dynamic>,
      ),
    );
  }

  final String status;
  final LibraryDocumentData document;
}

class LibraryDocumentSummary {
  LibraryDocumentSummary({
    required this.routePath,
    required this.sourcePath,
    required this.kind,
    required this.documentId,
    required this.title,
    required this.subjectId,
    required this.areaId,
    required this.pathwayId,
    required this.description,
  });

  factory LibraryDocumentSummary.fromJson(Map<String, dynamic> json) {
    return LibraryDocumentSummary(
      routePath: json['route_path'] as String,
      sourcePath: json['source_path'] as String,
      kind: json['kind'] as String,
      documentId: json['document_id'] as String,
      title: json['title'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      pathwayId: json['pathway_id'] as String,
      description: json['description'] as String,
    );
  }

  final String routePath;
  final String sourcePath;
  final String kind;
  final String documentId;
  final String title;
  final String subjectId;
  final String areaId;
  final String pathwayId;
  final String description;
}

class LibraryDocumentData extends LibraryDocumentSummary {
  LibraryDocumentData({
    required super.routePath,
    required super.sourcePath,
    required super.kind,
    required super.documentId,
    required super.title,
    required super.subjectId,
    required super.areaId,
    required super.pathwayId,
    required super.description,
    required this.body,
  });

  factory LibraryDocumentData.fromJson(Map<String, dynamic> json) {
    return LibraryDocumentData(
      routePath: json['route_path'] as String,
      sourcePath: json['source_path'] as String,
      kind: json['kind'] as String,
      documentId: json['document_id'] as String,
      title: json['title'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      pathwayId: json['pathway_id'] as String,
      description: json['description'] as String,
      body: json['body'] as String,
    );
  }

  final String body;
}

class LibraryBundle {
  LibraryBundle({
    required this.subjects,
    required this.areas,
    required this.pathways,
    required this.skills,
    required this.stages,
    required this.playlists,
    required this.materials,
  });

  factory LibraryBundle.fromJson(Map<String, dynamic> json) {
    return LibraryBundle(
      subjects: (json['subjects'] as List<dynamic>)
          .map((item) => SubjectInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      areas: (json['areas'] as List<dynamic>)
          .map((item) => AreaInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      pathways: ((json['pathways'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => PathwayInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      skills: (json['skills'] as List<dynamic>)
          .map((item) => SkillInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      stages: (json['stages'] as List<dynamic>)
          .map((item) => StageInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      playlists: (json['playlists'] as List<dynamic>)
          .map((item) => PlaylistInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      materials: (json['materials'] as List<dynamic>)
          .map((item) => MaterialInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<SubjectInfo> subjects;
  final List<AreaInfo> areas;
  final List<PathwayInfo> pathways;
  final List<SkillInfo> skills;
  final List<StageInfo> stages;
  final List<PlaylistInfo> playlists;
  final List<MaterialInfo> materials;
}

class LibraryReport {
  LibraryReport({
    required this.subjectCount,
    required this.areaCount,
    required this.pathwayCount,
    required this.skillCount,
    required this.stageCount,
    required this.playlistCount,
    required this.materialCount,
    required this.loadedAtUtc,
  });

  factory LibraryReport.fromJson(Map<String, dynamic> json) {
    return LibraryReport(
      subjectCount: (json['subject_count'] as num).toInt(),
      areaCount: (json['area_count'] as num).toInt(),
      pathwayCount: (json['pathway_count'] as num?)?.toInt() ?? 0,
      skillCount: (json['skill_count'] as num).toInt(),
      stageCount: (json['stage_count'] as num).toInt(),
      playlistCount: (json['playlist_count'] as num).toInt(),
      materialCount: (json['material_count'] as num).toInt(),
      loadedAtUtc: json['loaded_at_utc'] as String,
    );
  }

  final int subjectCount;
  final int areaCount;
  final int pathwayCount;
  final int skillCount;
  final int stageCount;
  final int playlistCount;
  final int materialCount;
  final String loadedAtUtc;
}

class TeamInfo {
  TeamInfo({
    required this.teamId,
    required this.displayName,
    required this.description,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      teamId: json['team_id'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String,
    );
  }

  final String teamId;
  final String displayName;
  final String description;
}

class ViewerUser {
  factory ViewerUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    final canManageTeam = json['can_manage_team'] as bool? ?? role != 'learner';
    return ViewerUser(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      role: role,
      currentLevel: json['current_level'] as String?,
      notes: json['notes'] as String? ?? '',
      learnerId: json['learner_id'] as String?,
      googleSignedIn: json['google_signed_in'] as bool? ?? false,
      googleDisplayName: json['google_display_name'] as String?,
      googlePictureUrl: json['google_picture_url'] as String?,
      googleEmail: json['google_email'] as String?,
      canManageTeam: canManageTeam,
      canReadLibrary: json['can_read_library'] as bool? ?? canManageTeam,
      canViewAllLearners:
          json['can_view_all_learners'] as bool? ?? canManageTeam,
      canOpenDeveloperDocs:
          json['can_open_developer_docs'] as bool? ?? role == 'owner',
    );
  }

  ViewerUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.notes,
    required this.canManageTeam,
    required this.canReadLibrary,
    required this.canViewAllLearners,
    required this.canOpenDeveloperDocs,
    this.currentLevel,
    this.learnerId,
    this.googleSignedIn = false,
    this.googleDisplayName,
    this.googlePictureUrl,
    this.googleEmail,
  });

  final String userId;
  final String username;
  final String displayName;
  final String role;
  final String notes;
  final String? currentLevel;
  final String? learnerId;
  final bool googleSignedIn;
  final String? googleDisplayName;
  final String? googlePictureUrl;
  final String? googleEmail;
  final bool canManageTeam;
  final bool canReadLibrary;
  final bool canViewAllLearners;
  final bool canOpenDeveloperDocs;

  bool get isLearner => role == 'learner';
  bool get isOwner => role == 'owner';

  String get profileLabel {
    final googleName = googleDisplayName?.trim();
    if (googleSignedIn && googleName != null && googleName.isNotEmpty) {
      return googleName;
    }
    return displayName;
  }

  String? get profilePictureUrl {
    if (!googleSignedIn) return null;
    final pictureUrl = googlePictureUrl?.trim();
    if (pictureUrl == null || pictureUrl.isEmpty) return null;
    return pictureUrl;
  }
}

class LearnerDashboard {
  LearnerDashboard({
    required this.learnerId,
    required this.displayName,
    required this.currentAge,
    required this.currentLevel,
    required this.notes,
    required this.attentionState,
    required this.attentionLabel,
    required this.nextActionLabel,
    required this.reviewItemCount,
    required this.progressStatusCounts,
    required this.stageProgress,
    this.activeAssignment,
    this.todaySession,
    this.latestEvidence,
  });

  factory LearnerDashboard.fromJson(Map<String, dynamic> json) {
    return LearnerDashboard(
      learnerId: json['learner_id'] as String,
      displayName: json['display_name'] as String,
      currentAge: (json['current_age'] as num).toInt(),
      currentLevel: json['current_level'] as String,
      notes: json['notes'] as String,
      attentionState: json['attention_state'] as String? ?? 'ready_now',
      attentionLabel: json['attention_label'] as String? ?? '',
      nextActionLabel: json['next_action_label'] as String? ?? '',
      reviewItemCount: (json['review_item_count'] as num).toInt(),
      progressStatusCounts:
          (json['progress_status_counts'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ),
      stageProgress: (json['stage_progress'] as List<dynamic>)
          .map((item) => StageProgress.fromJson(item as Map<String, dynamic>))
          .toList(),
      activeAssignment: json['active_assignment'] == null
          ? null
          : AssignmentSummary.fromJson(
              json['active_assignment'] as Map<String, dynamic>,
            ),
      todaySession: json['today_session'] == null
          ? null
          : SessionSummary.fromJson(
              json['today_session'] as Map<String, dynamic>,
            ),
      latestEvidence: json['latest_evidence'] == null
          ? null
          : EvidenceSummary.fromJson(
              json['latest_evidence'] as Map<String, dynamic>,
            ),
    );
  }

  final String learnerId;
  final String displayName;
  final int currentAge;
  final String currentLevel;
  final String notes;
  final String attentionState;
  final String attentionLabel;
  final String nextActionLabel;
  final int reviewItemCount;
  final Map<String, int> progressStatusCounts;
  final List<StageProgress> stageProgress;
  final AssignmentSummary? activeAssignment;
  final SessionSummary? todaySession;
  final EvidenceSummary? latestEvidence;
}

class LearnerDetailPayload {
  LearnerDetailPayload({
    required this.learner,
    required this.assignedJourneys,
    required this.assignedPathways,
    required this.sessions,
    required this.progress,
    required this.reviewItems,
    required this.workspace,
    this.activeAssignment,
    this.journey,
  });

  factory LearnerDetailPayload.fromJson(Map<String, dynamic> json) {
    final assignedJourneys =
        ((json['assigned_journeys'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (item) =>
                  LearnerAssignedJourney.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    var assignedPathways =
        ((json['assigned_pathways'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (item) =>
                  LearnerAssignedPathway.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    if (assignedPathways.isEmpty && assignedJourneys.isNotEmpty) {
      assignedPathways = LearnerAssignedPathway.groupFromJourneys(
        assignedJourneys,
      );
    }
    return LearnerDetailPayload(
      learner: LearnerSummary.fromJson(json['learner'] as Map<String, dynamic>),
      activeAssignment: json['active_assignment'] == null
          ? null
          : AssignmentSummary.fromJson(
              json['active_assignment'] as Map<String, dynamic>,
            ),
      journey: json['journey'] == null
          ? null
          : LearnerJourney.fromJson(json['journey'] as Map<String, dynamic>),
      assignedJourneys: assignedJourneys,
      assignedPathways: assignedPathways,
      sessions: (json['sessions'] as List<dynamic>)
          .map((item) => SessionDetail.fromJson(item as Map<String, dynamic>))
          .toList(),
      progress: (json['progress'] as List<dynamic>)
          .map(
            (item) =>
                SkillProgressSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      reviewItems: (json['review_items'] as List<dynamic>)
          .map((item) => ReviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      workspace: LearnerWorkspace.fromJson(
        json['workspace'] as Map<String, dynamic>,
      ),
    );
  }

  final LearnerSummary learner;
  final AssignmentSummary? activeAssignment;
  final LearnerJourney? journey;
  final List<LearnerAssignedJourney> assignedJourneys;
  final List<LearnerAssignedPathway> assignedPathways;
  final List<SessionDetail> sessions;
  final List<SkillProgressSummary> progress;
  final List<ReviewItem> reviewItems;
  final LearnerWorkspace workspace;
}

class LearnerWorkspacePayload {
  LearnerWorkspacePayload({
    required this.status,
    required this.workspaceView,
    required this.viewerRole,
    required this.includesAdultMaterials,
    required this.learner,
    required this.assignedJourneys,
    required this.assignedPathways,
    required this.sessions,
    required this.progress,
    required this.reviewItems,
    required this.workspace,
    this.activeAssignment,
    this.journey,
  });

  factory LearnerWorkspacePayload.fromJson(Map<String, dynamic> json) {
    final assignedJourneys =
        ((json['assigned_journeys'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (item) =>
                  LearnerAssignedJourney.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    var assignedPathways =
        ((json['assigned_pathways'] as List<dynamic>?) ?? const <dynamic>[])
            .map(
              (item) =>
                  LearnerAssignedPathway.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    if (assignedPathways.isEmpty && assignedJourneys.isNotEmpty) {
      assignedPathways = LearnerAssignedPathway.groupFromJourneys(
        assignedJourneys,
      );
    }
    return LearnerWorkspacePayload(
      status: json['status'] as String,
      workspaceView: json['workspace_view'] as String? ?? 'learner',
      viewerRole: json['viewer_role'] as String? ?? 'learner',
      includesAdultMaterials:
          json['includes_adult_materials'] as bool? ?? false,
      learner: LearnerSummary.fromJson(json['learner'] as Map<String, dynamic>),
      activeAssignment: json['active_assignment'] == null
          ? null
          : AssignmentSummary.fromJson(
              json['active_assignment'] as Map<String, dynamic>,
            ),
      journey: json['journey'] == null
          ? null
          : LearnerJourney.fromJson(json['journey'] as Map<String, dynamic>),
      assignedJourneys: assignedJourneys,
      assignedPathways: assignedPathways,
      sessions: (json['sessions'] as List<dynamic>)
          .map((item) => SessionDetail.fromJson(item as Map<String, dynamic>))
          .toList(),
      progress: (json['progress'] as List<dynamic>)
          .map(
            (item) =>
                SkillProgressSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      reviewItems: (json['review_items'] as List<dynamic>)
          .map((item) => ReviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      workspace: LearnerWorkspace.fromJson(
        json['workspace'] as Map<String, dynamic>,
      ),
    );
  }

  final String status;
  final String workspaceView;
  final String viewerRole;
  final bool includesAdultMaterials;
  final LearnerSummary learner;
  final AssignmentSummary? activeAssignment;
  final LearnerJourney? journey;
  final List<LearnerAssignedJourney> assignedJourneys;
  final List<LearnerAssignedPathway> assignedPathways;
  final List<SessionDetail> sessions;
  final List<SkillProgressSummary> progress;
  final List<ReviewItem> reviewItems;
  final LearnerWorkspace workspace;
}

class LearnerWorkspace {
  LearnerWorkspace({
    required this.attentionLabel,
    required this.practiceLane,
    required this.progressSnapshot,
    required this.recentWins,
    this.continueBlock,
  });

  factory LearnerWorkspace.fromJson(Map<String, dynamic> json) {
    return LearnerWorkspace(
      attentionLabel: json['attention_label'] as String? ?? '',
      continueBlock: json['continue_block'] == null
          ? null
          : LearnerContinueBlock.fromJson(
              json['continue_block'] as Map<String, dynamic>,
            ),
      practiceLane: (json['practice_lane'] as List<dynamic>)
          .map((item) => SessionDetail.fromJson(item as Map<String, dynamic>))
          .toList(),
      progressSnapshot: LearnerProgressSnapshot.fromJson(
        json['progress_snapshot'] as Map<String, dynamic>,
      ),
      recentWins: (json['recent_wins'] as List<dynamic>)
          .map(
            (item) => LearnerRecentWin.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String attentionLabel;
  final LearnerContinueBlock? continueBlock;
  final List<SessionDetail> practiceLane;
  final LearnerProgressSnapshot progressSnapshot;
  final List<LearnerRecentWin> recentWins;
}

class LearnerContinueBlock {
  LearnerContinueBlock({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.session,
  });

  factory LearnerContinueBlock.fromJson(Map<String, dynamic> json) {
    return LearnerContinueBlock(
      title: json['title'] as String,
      description: json['description'] as String,
      actionLabel: json['action_label'] as String,
      session: SessionDetail.fromJson(json['session'] as Map<String, dynamic>),
    );
  }

  final String title;
  final String description;
  final String actionLabel;
  final SessionDetail session;
}

class LearnerAssignedJourney {
  LearnerAssignedJourney({
    required this.assignment,
    required this.journey,
    required this.sessions,
    this.currentSessionId,
    this.continueBlock,
  });

  factory LearnerAssignedJourney.fromJson(Map<String, dynamic> json) {
    return LearnerAssignedJourney(
      assignment: AssignmentSummary.fromJson(
        json['assignment'] as Map<String, dynamic>,
      ),
      journey: LearnerJourney.fromJson(json['journey'] as Map<String, dynamic>),
      currentSessionId: json['current_session_id'] as String?,
      continueBlock: json['continue_block'] == null
          ? null
          : LearnerContinueBlock.fromJson(
              json['continue_block'] as Map<String, dynamic>,
            ),
      sessions: (json['sessions'] as List<dynamic>)
          .map((item) => SessionDetail.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final AssignmentSummary assignment;
  final LearnerJourney journey;
  final String? currentSessionId;
  final LearnerContinueBlock? continueBlock;
  final List<SessionDetail> sessions;
}

class LearnerAssignedPathway {
  LearnerAssignedPathway({
    required this.pathwayTitle,
    required this.pathwayDescription,
    required this.playlistCount,
    required this.totalSessionCount,
    required this.completedSessionCount,
    required this.pendingSessionCount,
    required this.assignedPlaylists,
    this.pathwayId,
    this.pathwayRoutePath,
  });

  factory LearnerAssignedPathway.fromJson(Map<String, dynamic> json) {
    return LearnerAssignedPathway(
      pathwayId: json['pathway_id'] as String?,
      pathwayTitle: json['pathway_title'] as String? ?? 'Assigned pathway',
      pathwayDescription: json['pathway_description'] as String? ?? '',
      pathwayRoutePath: json['pathway_route_path'] as String?,
      playlistCount: (json['playlist_count'] as num?)?.toInt() ?? 0,
      totalSessionCount: (json['total_session_count'] as num?)?.toInt() ?? 0,
      completedSessionCount:
          (json['completed_session_count'] as num?)?.toInt() ?? 0,
      pendingSessionCount:
          (json['pending_session_count'] as num?)?.toInt() ?? 0,
      assignedPlaylists:
          ((json['assigned_playlists'] as List<dynamic>?) ?? const <dynamic>[])
              .map(
                (item) => LearnerAssignedJourney.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  static List<LearnerAssignedPathway> groupFromJourneys(
    List<LearnerAssignedJourney> journeys,
  ) {
    final groupedJourneys = <String, List<LearnerAssignedJourney>>{};
    final orderedKeys = <String>[];
    final pathwayMeta = <String, LearnerJourney>{};

    for (final assignedJourney in journeys) {
      final key = _groupKey(assignedJourney.journey);
      if (!groupedJourneys.containsKey(key)) {
        orderedKeys.add(key);
      }
      groupedJourneys
          .putIfAbsent(key, () => <LearnerAssignedJourney>[])
          .add(assignedJourney);
      pathwayMeta[key] = assignedJourney.journey;
    }

    return orderedKeys
        .map((key) {
          final grouped =
              groupedJourneys[key] ?? const <LearnerAssignedJourney>[];
          final meta = pathwayMeta[key]!;
          return LearnerAssignedPathway(
            pathwayId: meta.pathwayId,
            pathwayTitle: meta.pathwayTitle ?? meta.playlistTitle,
            pathwayDescription: meta.pathwayDescription ?? '',
            pathwayRoutePath: meta.pathwayRoutePath,
            playlistCount: grouped.length,
            totalSessionCount: grouped.fold<int>(
              0,
              (count, item) => count + item.journey.totalSessionCount,
            ),
            completedSessionCount: grouped.fold<int>(
              0,
              (count, item) => count + item.journey.completedSessionCount,
            ),
            pendingSessionCount: grouped.fold<int>(
              0,
              (count, item) => count + item.journey.pendingSessionCount,
            ),
            assignedPlaylists: grouped,
          );
        })
        .toList(growable: false);
  }

  static String _groupKey(LearnerJourney journey) {
    return journey.pathwayId ?? 'playlist:${journey.playlistId}';
  }

  final String? pathwayId;
  final String pathwayTitle;
  final String pathwayDescription;
  final String? pathwayRoutePath;
  final int playlistCount;
  final int totalSessionCount;
  final int completedSessionCount;
  final int pendingSessionCount;
  final List<LearnerAssignedJourney> assignedPlaylists;
}

class LearnerProgressSnapshot {
  LearnerProgressSnapshot({
    required this.secureCount,
    required this.developingCount,
    required this.notStartedCount,
    required this.reviewItemCount,
    required this.completedSessionCount,
    required this.pendingSessionCount,
  });

  factory LearnerProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return LearnerProgressSnapshot(
      secureCount: (json['secure_count'] as num).toInt(),
      developingCount: (json['developing_count'] as num).toInt(),
      notStartedCount: (json['not_started_count'] as num).toInt(),
      reviewItemCount: (json['review_item_count'] as num).toInt(),
      completedSessionCount: (json['completed_session_count'] as num).toInt(),
      pendingSessionCount: (json['pending_session_count'] as num).toInt(),
    );
  }

  final int secureCount;
  final int developingCount;
  final int notStartedCount;
  final int reviewItemCount;
  final int completedSessionCount;
  final int pendingSessionCount;
}

class LearnerRecentWin {
  LearnerRecentWin({
    required this.sessionId,
    required this.sessionTitle,
    required this.scoreLabel,
    required this.notes,
    required this.recordedAt,
  });

  factory LearnerRecentWin.fromJson(Map<String, dynamic> json) {
    return LearnerRecentWin(
      sessionId: json['session_id'] as String,
      sessionTitle: json['session_title'] as String,
      scoreLabel: json['score_label'] as String,
      notes: json['notes'] as String? ?? '',
      recordedAt: json['recorded_at'] as String,
    );
  }

  final String sessionId;
  final String sessionTitle;
  final String scoreLabel;
  final String notes;
  final String recordedAt;
}

class LearnerJourney {
  LearnerJourney({
    required this.playlistId,
    required this.playlistTitle,
    required this.playlistDescription,
    required this.recommendedAge,
    required this.recommendedLevel,
    required this.durationDays,
    required this.totalSessionCount,
    required this.completedSessionCount,
    required this.pendingSessionCount,
    required this.totalMaterialCount,
    required this.liveMaterialCount,
    this.pathwayId,
    this.pathwayTitle,
    this.pathwayDescription,
    this.pathwayRoutePath,
    this.playlistRoutePath,
    this.nextSessionId,
  });

  factory LearnerJourney.fromJson(Map<String, dynamic> json) {
    return LearnerJourney(
      pathwayId: json['pathway_id'] as String?,
      pathwayTitle: json['pathway_title'] as String?,
      pathwayDescription: json['pathway_description'] as String?,
      pathwayRoutePath: json['pathway_route_path'] as String?,
      playlistId: json['playlist_id'] as String,
      playlistTitle: json['playlist_title'] as String,
      playlistDescription: json['playlist_description'] as String,
      playlistRoutePath: json['playlist_route_path'] as String?,
      recommendedAge: (json['recommended_age'] as num).toInt(),
      recommendedLevel: json['recommended_level'] as String,
      durationDays: (json['duration_days'] as num).toInt(),
      totalSessionCount: (json['total_session_count'] as num).toInt(),
      completedSessionCount: (json['completed_session_count'] as num).toInt(),
      pendingSessionCount: (json['pending_session_count'] as num).toInt(),
      totalMaterialCount: (json['total_material_count'] as num).toInt(),
      liveMaterialCount: (json['live_material_count'] as num).toInt(),
      nextSessionId: json['next_session_id'] as String?,
    );
  }

  final String? pathwayId;
  final String? pathwayTitle;
  final String? pathwayDescription;
  final String? pathwayRoutePath;
  final String playlistId;
  final String playlistTitle;
  final String playlistDescription;
  final String? playlistRoutePath;
  final int recommendedAge;
  final String recommendedLevel;
  final int durationDays;
  final int totalSessionCount;
  final int completedSessionCount;
  final int pendingSessionCount;
  final int totalMaterialCount;
  final int liveMaterialCount;
  final String? nextSessionId;
}

class LearnerSummary {
  LearnerSummary({
    required this.learnerId,
    required this.displayName,
    required this.currentAge,
    required this.currentLevel,
    required this.notes,
  });

  factory LearnerSummary.fromJson(Map<String, dynamic> json) {
    return LearnerSummary(
      learnerId: json['learner_id'] as String,
      displayName: json['display_name'] as String,
      currentAge: (json['current_age'] as num).toInt(),
      currentLevel: json['current_level'] as String,
      notes: json['notes'] as String,
    );
  }

  final String learnerId;
  final String displayName;
  final int currentAge;
  final String currentLevel;
  final String notes;
}

class AssignmentSummary {
  AssignmentSummary({
    required this.assignmentId,
    required this.playlistId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalSessions,
    required this.completedSessions,
    required this.completionPercent,
  });

  factory AssignmentSummary.fromJson(Map<String, dynamic> json) {
    return AssignmentSummary(
      assignmentId: json['assignment_id'] as String,
      playlistId: json['playlist_id'] as String,
      title: json['title'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      status: json['status'] as String,
      totalSessions: (json['total_sessions'] as num).toInt(),
      completedSessions: (json['completed_sessions'] as num).toInt(),
      completionPercent: (json['completion_percent'] as num).toInt(),
    );
  }

  final String assignmentId;
  final String playlistId;
  final String title;
  final String startDate;
  final String endDate;
  final String status;
  final int totalSessions;
  final int completedSessions;
  final int completionPercent;
}

class SessionSummary {
  SessionSummary({
    required this.sessionId,
    required this.title,
    required this.scheduledDate,
    required this.status,
    required this.dayOffset,
    this.sequenceNumber,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['session_id'] as String,
      title: json['title'] as String,
      scheduledDate: json['scheduled_date'] as String,
      status: json['status'] as String,
      dayOffset: (json['day_offset'] as num).toInt(),
      sequenceNumber: (json['sequence_number'] as num?)?.toInt(),
    );
  }

  final String sessionId;
  final String title;
  final String scheduledDate;
  final String status;
  final int dayOffset;
  final int? sequenceNumber;
}

class SessionDetail extends SessionSummary {
  SessionDetail({
    required super.sessionId,
    required super.title,
    required super.scheduledDate,
    required super.status,
    required super.dayOffset,
    super.sequenceNumber,
    required this.dominantKind,
    required this.requiresAdultSupport,
    required this.estimatedMinutes,
    required this.liveMaterialCount,
    required this.learnerMaterialCount,
    required this.adultMaterialCount,
    required this.notes,
    required this.materialsByKind,
    required this.materials,
    this.latestEvidence,
  });

  factory SessionDetail.fromJson(Map<String, dynamic> json) {
    return SessionDetail(
      sessionId: json['session_id'] as String,
      title: json['title'] as String,
      scheduledDate: json['scheduled_date'] as String,
      status: json['status'] as String,
      dayOffset: (json['day_offset'] as num).toInt(),
      sequenceNumber: (json['sequence_number'] as num?)?.toInt(),
      dominantKind: json['dominant_kind'] as String,
      requiresAdultSupport: json['requires_adult_support'] as bool? ?? false,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 0,
      liveMaterialCount: (json['live_material_count'] as num?)?.toInt() ?? 0,
      learnerMaterialCount:
          (json['learner_material_count'] as num?)?.toInt() ?? 0,
      adultMaterialCount: (json['adult_material_count'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String,
      materialsByKind: (json['materials_by_kind'] as List<dynamic>)
          .map(
            (item) =>
                SessionMaterialKindGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      materials: (json['materials'] as List<dynamic>)
          .map((item) => SessionMaterial.fromJson(item as Map<String, dynamic>))
          .toList(),
      latestEvidence: json['latest_evidence'] == null
          ? null
          : EvidenceSummary.fromJson(
              json['latest_evidence'] as Map<String, dynamic>,
            ),
    );
  }

  final String dominantKind;
  final bool requiresAdultSupport;
  final int estimatedMinutes;
  final int liveMaterialCount;
  final int learnerMaterialCount;
  final int adultMaterialCount;
  final String notes;
  final List<SessionMaterialKindGroup> materialsByKind;
  final List<SessionMaterial> materials;
  final EvidenceSummary? latestEvidence;
}

class SessionMaterial {
  SessionMaterial({
    required this.sessionMaterialId,
    required this.title,
    required this.materialId,
    required this.kind,
    required this.audience,
    required this.estimatedMinutes,
    required this.skillIds,
    required this.status,
    this.documentRoutePath,
    this.documentBody,
    this.runtime,
    this.proficiency,
    this.gate,
  });

  factory SessionMaterial.fromJson(Map<String, dynamic> json) {
    return SessionMaterial(
      sessionMaterialId: json['session_material_id'] as String,
      title: json['title'] as String,
      materialId: json['material_id'] as String,
      kind: json['kind'] as String,
      audience: json['audience'] as String,
      estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      status: json['status'] as String,
      documentRoutePath: json['document_route_path'] as String?,
      documentBody: json['document_body'] as String?,
      runtime: json['runtime'] == null
          ? null
          : SessionMaterialRuntimeSummary.fromJson(
              json['runtime'] as Map<String, dynamic>,
            ),
      proficiency: json['proficiency'] == null
          ? null
          : SessionMaterialProficiencySummary.fromJson(
              json['proficiency'] as Map<String, dynamic>,
            ),
      gate: json['gate'] == null
          ? null
          : SessionMaterialGateSummary.fromJson(
              json['gate'] as Map<String, dynamic>,
            ),
    );
  }

  final String sessionMaterialId;
  final String title;
  final String materialId;
  final String kind;
  final String audience;
  final int estimatedMinutes;
  final List<String> skillIds;
  final String status;
  final String? documentRoutePath;
  final String? documentBody;
  final SessionMaterialRuntimeSummary? runtime;
  final SessionMaterialProficiencySummary? proficiency;
  final SessionMaterialGateSummary? gate;

  bool get isAdultFacing => audience == 'adult';
  bool get isLearnerFacing => audience == 'learner';
  bool get isExecutable => runtime?.executable ?? false;
  bool get canStartActivity => isExecutable && (gate?.enabled ?? true);
}

class SessionMaterialKindGroup {
  SessionMaterialKindGroup({
    required this.kind,
    required this.audience,
    required this.materialCount,
    required this.materials,
  });

  factory SessionMaterialKindGroup.fromJson(Map<String, dynamic> json) {
    return SessionMaterialKindGroup(
      kind: json['kind'] as String,
      audience: json['audience'] as String,
      materialCount: (json['material_count'] as num).toInt(),
      materials: (json['materials'] as List<dynamic>)
          .map((item) => SessionMaterial.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String kind;
  final String audience;
  final int materialCount;
  final List<SessionMaterial> materials;
}

class SessionMaterialRuntimeSummary {
  SessionMaterialRuntimeSummary({
    required this.runtimeId,
    required this.engineId,
    required this.templateId,
    required this.executable,
  });

  factory SessionMaterialRuntimeSummary.fromJson(Map<String, dynamic> json) {
    return SessionMaterialRuntimeSummary(
      runtimeId: json['runtime_id'] as String,
      engineId: json['engine_id'] as String,
      templateId: json['template_id'] as String,
      executable: json['executable'] as bool? ?? true,
    );
  }

  final String runtimeId;
  final String engineId;
  final String templateId;
  final bool executable;
}

class SessionMaterialProficiencySummary {
  SessionMaterialProficiencySummary({
    required this.minAttempts,
    required this.windowSize,
    required this.targetAccuracy,
    required this.consecutivePassesRequired,
    required this.attemptCount,
    required this.recentAttemptCount,
    required this.recentAverageAccuracy,
    required this.consecutivePassCount,
    required this.bestCorrectCount,
    required this.readyToMoveOn,
    required this.verdict,
    required this.verdictLabel,
    required this.detailLabel,
    this.targetCorrectCount,
  });

  factory SessionMaterialProficiencySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return SessionMaterialProficiencySummary(
      minAttempts: (json['min_attempts'] as num).toInt(),
      windowSize: (json['window_size'] as num).toInt(),
      targetAccuracy: (json['target_accuracy'] as num).toDouble(),
      consecutivePassesRequired: (json['consecutive_passes_required'] as num)
          .toInt(),
      targetCorrectCount: (json['target_correct_count'] as num?)?.toInt(),
      attemptCount: (json['attempt_count'] as num).toInt(),
      recentAttemptCount: (json['recent_attempt_count'] as num).toInt(),
      recentAverageAccuracy: (json['recent_average_accuracy'] as num)
          .toDouble(),
      consecutivePassCount: (json['consecutive_pass_count'] as num).toInt(),
      bestCorrectCount: (json['best_correct_count'] as num).toInt(),
      readyToMoveOn: json['ready_to_move_on'] as bool? ?? false,
      verdict: json['verdict'] as String,
      verdictLabel: json['verdict_label'] as String,
      detailLabel: json['detail_label'] as String,
    );
  }

  final int minAttempts;
  final int windowSize;
  final double targetAccuracy;
  final int consecutivePassesRequired;
  final int? targetCorrectCount;
  final int attemptCount;
  final int recentAttemptCount;
  final double recentAverageAccuracy;
  final int consecutivePassCount;
  final int bestCorrectCount;
  final bool readyToMoveOn;
  final String verdict;
  final String verdictLabel;
  final String detailLabel;
}

class SessionMaterialGateSummary {
  SessionMaterialGateSummary({
    required this.enabled,
    required this.prerequisiteMaterialId,
    required this.prerequisiteTitle,
    required this.prerequisiteVerdict,
    required this.reasonLabel,
  });

  factory SessionMaterialGateSummary.fromJson(Map<String, dynamic> json) {
    return SessionMaterialGateSummary(
      enabled: json['enabled'] as bool? ?? false,
      prerequisiteMaterialId: json['prerequisite_material_id'] as String,
      prerequisiteTitle: json['prerequisite_title'] as String,
      prerequisiteVerdict: json['prerequisite_verdict'] as String,
      reasonLabel: json['reason_label'] as String,
    );
  }

  final bool enabled;
  final String prerequisiteMaterialId;
  final String prerequisiteTitle;
  final String prerequisiteVerdict;
  final String reasonLabel;
}

class EvidenceSummary {
  EvidenceSummary({
    required this.evidenceId,
    required this.score,
    required this.maxScore,
    required this.durationMinutes,
    required this.notes,
    required this.recordedAt,
  });

  factory EvidenceSummary.fromJson(Map<String, dynamic> json) {
    return EvidenceSummary(
      evidenceId: json['evidence_id'] as String,
      score: (json['score'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      notes: json['notes'] as String,
      recordedAt: json['recorded_at'] as String,
    );
  }

  final String evidenceId;
  final double score;
  final double maxScore;
  final int durationMinutes;
  final String notes;
  final String recordedAt;
}

class SkillProgressSummary {
  SkillProgressSummary({
    required this.skillId,
    required this.status,
    required this.scoreAverage,
    required this.lastScore,
    required this.totalEvidence,
    this.lastEvidenceAt,
  });

  factory SkillProgressSummary.fromJson(Map<String, dynamic> json) {
    return SkillProgressSummary(
      skillId: json['skill_id'] as String,
      status: json['status'] as String,
      scoreAverage: (json['score_average'] as num).toDouble(),
      lastScore: (json['last_score'] as num).toDouble(),
      totalEvidence: (json['total_evidence'] as num).toInt(),
      lastEvidenceAt: json['last_evidence_at'] as String?,
    );
  }

  final String skillId;
  final String status;
  final double scoreAverage;
  final double lastScore;
  final int totalEvidence;
  final String? lastEvidenceAt;
}

class ReviewItem {
  ReviewItem({
    required this.reviewItemId,
    required this.skillId,
    required this.reason,
    required this.dueDate,
    required this.status,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      reviewItemId: json['review_item_id'] as String,
      skillId: json['skill_id'] as String,
      reason: json['reason'] as String,
      dueDate: json['due_date'] as String,
      status: json['status'] as String,
    );
  }

  final String reviewItemId;
  final String skillId;
  final String reason;
  final String dueDate;
  final String status;
}

class StageProgress {
  StageProgress({
    required this.stageId,
    required this.title,
    required this.completedSkills,
    required this.totalSkills,
  });

  factory StageProgress.fromJson(Map<String, dynamic> json) {
    return StageProgress(
      stageId: json['stage_id'] as String,
      title: json['title'] as String,
      completedSkills: (json['completed_skills'] as num).toInt(),
      totalSkills: (json['total_skills'] as num).toInt(),
    );
  }

  final String stageId;
  final String title;
  final int completedSkills;
  final int totalSkills;
}

class SubjectInfo {
  SubjectInfo({
    required this.subjectId,
    required this.title,
    required this.description,
  });

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    return SubjectInfo(
      subjectId: json['subject_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  final String subjectId;
  final String title;
  final String description;
}

class AreaInfo {
  AreaInfo({
    required this.areaId,
    required this.subjectId,
    required this.title,
    required this.description,
  });

  factory AreaInfo.fromJson(Map<String, dynamic> json) {
    return AreaInfo(
      areaId: json['area_id'] as String,
      subjectId: json['subject_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  final String areaId;
  final String subjectId;
  final String title;
  final String description;
}

class PathwayInfo {
  PathwayInfo({
    required this.pathwayId,
    required this.title,
    required this.subjectId,
    required this.areaId,
    required this.recommendedAgeMin,
    required this.recommendedAgeMax,
    required this.stageIds,
    required this.playlistIds,
    required this.entryPoints,
    required this.description,
    required this.sourcePath,
  });

  factory PathwayInfo.fromJson(Map<String, dynamic> json) {
    return PathwayInfo(
      pathwayId: json['pathway_id'] as String,
      title: json['title'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      recommendedAgeMin: (json['recommended_age_min'] as num).toInt(),
      recommendedAgeMax: (json['recommended_age_max'] as num).toInt(),
      stageIds: (json['stage_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      playlistIds: (json['playlist_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      entryPoints: (json['entry_points'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      description: json['description'] as String,
      sourcePath: json['source_path'] as String,
    );
  }

  final String pathwayId;
  final String title;
  final String subjectId;
  final String areaId;
  final int recommendedAgeMin;
  final int recommendedAgeMax;
  final List<String> stageIds;
  final List<String> playlistIds;
  final Map<String, String> entryPoints;
  final String description;
  final String sourcePath;
}

class SkillInfo {
  SkillInfo({
    required this.skillId,
    required this.subjectId,
    required this.areaId,
    required this.title,
    required this.recommendedAge,
    required this.recommendedLevel,
    required this.description,
    required this.successCriteria,
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) {
    return SkillInfo(
      skillId: json['skill_id'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      title: json['title'] as String,
      recommendedAge: (json['recommended_age'] as num).toInt(),
      recommendedLevel: json['recommended_level'] as String,
      description: json['description'] as String,
      successCriteria: json['success_criteria'] as String,
    );
  }

  final String skillId;
  final String subjectId;
  final String areaId;
  final String title;
  final int recommendedAge;
  final String recommendedLevel;
  final String description;
  final String successCriteria;
}

class StageInfo {
  StageInfo({
    required this.stageId,
    required this.subjectId,
    required this.areaId,
    required this.title,
    required this.recommendedAge,
    required this.recommendedLevel,
    required this.description,
    required this.skillIds,
  });

  factory StageInfo.fromJson(Map<String, dynamic> json) {
    return StageInfo(
      stageId: json['stage_id'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      title: json['title'] as String,
      recommendedAge: (json['recommended_age'] as num).toInt(),
      recommendedLevel: json['recommended_level'] as String,
      description: json['description'] as String,
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
    );
  }

  final String stageId;
  final String subjectId;
  final String areaId;
  final String title;
  final int recommendedAge;
  final String recommendedLevel;
  final String description;
  final List<String> skillIds;
}

class PlaylistInfo {
  PlaylistInfo({
    required this.playlistId,
    required this.title,
    required this.subjectId,
    required this.areaId,
    required this.recommendedAge,
    required this.recommendedLevel,
    required this.stageIds,
    required this.skillIds,
    required this.durationDays,
    required this.sessions,
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final sessionPattern = json['session_pattern'] as Map<String, dynamic>?;
    return PlaylistInfo(
      playlistId: json['playlist_id'] as String,
      title: json['title'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      recommendedAge: (json['recommended_age'] as num).toInt(),
      recommendedLevel: json['recommended_level'] as String,
      stageIds: (json['stage_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      durationDays: (json['duration_days'] as num).toInt(),
      sessions:
          ((sessionPattern?['sessions'] as List<dynamic>?) ?? const <dynamic>[])
              .map(
                (item) =>
                    PlaylistSessionInfo.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  final String playlistId;
  final String title;
  final String subjectId;
  final String areaId;
  final int recommendedAge;
  final String recommendedLevel;
  final List<String> stageIds;
  final List<String> skillIds;
  final int durationDays;
  final List<PlaylistSessionInfo> sessions;
}

class PlaylistSessionInfo {
  PlaylistSessionInfo({
    required this.dayOffset,
    required this.title,
    required this.skillIds,
    required this.materialIds,
  });

  factory PlaylistSessionInfo.fromJson(Map<String, dynamic> json) {
    return PlaylistSessionInfo(
      dayOffset: (json['day_offset'] as num).toInt(),
      title: json['title'] as String,
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      materialIds: (json['material_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
    );
  }

  final int dayOffset;
  final String title;
  final List<String> skillIds;
  final List<String> materialIds;
}

class MaterialInfo {
  MaterialInfo({
    required this.id,
    required this.title,
    required this.kind,
    required this.subjectId,
    required this.areaId,
    required this.skillIds,
    required this.stageIds,
    required this.recommendedAge,
    required this.difficulty,
    required this.estimatedMinutes,
    this.runtime,
  });

  factory MaterialInfo.fromJson(Map<String, dynamic> json) {
    return MaterialInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: json['type'] as String,
      subjectId: json['subject_id'] as String,
      areaId: json['area_id'] as String,
      skillIds: (json['skill_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      stageIds: (json['stage_ids'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      recommendedAge: (json['recommended_age'] as num).toInt(),
      difficulty: json['difficulty'] as String,
      estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
      runtime: json['runtime'] == null
          ? null
          : MaterialRuntimeInfo.fromJson(
              json['runtime'] as Map<String, dynamic>,
            ),
    );
  }

  final String id;
  final String title;
  final String kind;
  final String subjectId;
  final String areaId;
  final List<String> skillIds;
  final List<String> stageIds;
  final int recommendedAge;
  final String difficulty;
  final int estimatedMinutes;
  final MaterialRuntimeInfo? runtime;
}

class MaterialRuntimeInfo {
  MaterialRuntimeInfo({
    required this.engineId,
    required this.specVersion,
    required this.templateId,
    required this.parameters,
    this.scoring,
    this.persistence,
  });

  factory MaterialRuntimeInfo.fromJson(Map<String, dynamic> json) {
    return MaterialRuntimeInfo(
      engineId: json['engine_id'] as String,
      specVersion: (json['spec_version'] as num).toInt(),
      templateId: json['template_id'] as String,
      parameters:
          (json['parameters'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      scoring: json['scoring'] == null
          ? null
          : MaterialRuntimeScoringInfo.fromJson(
              json['scoring'] as Map<String, dynamic>,
            ),
      persistence: json['persistence'] == null
          ? null
          : MaterialRuntimePersistenceInfo.fromJson(
              json['persistence'] as Map<String, dynamic>,
            ),
    );
  }

  final String engineId;
  final int specVersion;
  final String templateId;
  final Map<String, dynamic> parameters;
  final MaterialRuntimeScoringInfo? scoring;
  final MaterialRuntimePersistenceInfo? persistence;
}

class MaterialRuntimeScoringInfo {
  MaterialRuntimeScoringInfo({this.passAccuracy, this.softTimeLimitSeconds});

  factory MaterialRuntimeScoringInfo.fromJson(Map<String, dynamic> json) {
    return MaterialRuntimeScoringInfo(
      passAccuracy: (json['pass_accuracy'] as num?)?.toDouble(),
      softTimeLimitSeconds: (json['soft_time_limit_seconds'] as num?)?.toInt(),
    );
  }

  final double? passAccuracy;
  final int? softTimeLimitSeconds;
}

class MaterialRuntimePersistenceInfo {
  MaterialRuntimePersistenceInfo({
    required this.storeResponseLog,
    required this.storeSummary,
  });

  factory MaterialRuntimePersistenceInfo.fromJson(Map<String, dynamic> json) {
    return MaterialRuntimePersistenceInfo(
      storeResponseLog: json['store_response_log'] as bool? ?? false,
      storeSummary: json['store_summary'] as bool? ?? true,
    );
  }

  final bool storeResponseLog;
  final bool storeSummary;
}

class ActivityStartPayload {
  ActivityStartPayload({required this.status, required this.activity});

  factory ActivityStartPayload.fromJson(Map<String, dynamic> json) {
    return ActivityStartPayload(
      status: json['status'] as String,
      activity: ActivityInstance.fromJson(
        json['activity'] as Map<String, dynamic>,
      ),
    );
  }

  final String status;
  final ActivityInstance activity;
}

class ActivityInstance {
  ActivityInstance({
    required this.activityInstanceId,
    required this.sessionId,
    required this.sessionMaterialId,
    required this.materialId,
    required this.materialTitle,
    required this.runtimeId,
    required this.engineId,
    required this.templateId,
    required this.instructions,
    required this.estimatedMinutes,
    required this.scoring,
    required this.items,
  });

  factory ActivityInstance.fromJson(Map<String, dynamic> json) {
    return ActivityInstance(
      activityInstanceId: json['activity_instance_id'] as String,
      sessionId: json['session_id'] as String,
      sessionMaterialId: json['session_material_id'] as String,
      materialId: json['material_id'] as String,
      materialTitle: json['material_title'] as String,
      runtimeId: json['runtime_id'] as String,
      engineId: json['engine_id'] as String,
      templateId: json['template_id'] as String,
      instructions: json['instructions'] as String,
      estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
      scoring: ActivityScoringSummary.fromJson(
        json['scoring'] as Map<String, dynamic>,
      ),
      items: (json['items'] as List<dynamic>)
          .map((item) => ActivityItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String activityInstanceId;
  final String sessionId;
  final String sessionMaterialId;
  final String materialId;
  final String materialTitle;
  final String runtimeId;
  final String engineId;
  final String templateId;
  final String instructions;
  final int estimatedMinutes;
  final ActivityScoringSummary scoring;
  final List<ActivityItem> items;
}

class ActivityScoringSummary {
  ActivityScoringSummary({this.passAccuracy, this.softTimeLimitSeconds});

  factory ActivityScoringSummary.fromJson(Map<String, dynamic> json) {
    return ActivityScoringSummary(
      passAccuracy: (json['pass_accuracy'] as num?)?.toDouble(),
      softTimeLimitSeconds: (json['soft_time_limit_seconds'] as num?)?.toInt(),
    );
  }

  final double? passAccuracy;
  final int? softTimeLimitSeconds;
}

class ActivityItem {
  ActivityItem({
    required this.itemId,
    required this.content,
    required this.responseKind,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      itemId: json['item_id'] as String,
      content: json['content'] as String,
      responseKind: json['response_kind'] as String,
    );
  }

  final String itemId;
  final String content;
  final String responseKind;
}

class CompleteActivityResponse {
  CompleteActivityResponse({
    required this.status,
    required this.evidence,
    required this.updatedProgress,
    required this.activitySummary,
    this.proficiency,
  });

  factory CompleteActivityResponse.fromJson(Map<String, dynamic> json) {
    return CompleteActivityResponse(
      status: json['status'] as String,
      evidence: EvidenceSummary.fromJson(
        json['evidence'] as Map<String, dynamic>,
      ),
      updatedProgress: (json['updated_progress'] as List<dynamic>)
          .map(
            (item) =>
                SkillProgressSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      activitySummary: ActivitySummary.fromJson(
        json['activity_summary'] as Map<String, dynamic>,
      ),
      proficiency: json['proficiency'] == null
          ? null
          : SessionMaterialProficiencySummary.fromJson(
              json['proficiency'] as Map<String, dynamic>,
            ),
    );
  }

  final String status;
  final EvidenceSummary evidence;
  final List<SkillProgressSummary> updatedProgress;
  final ActivitySummary activitySummary;
  final SessionMaterialProficiencySummary? proficiency;
}

class ActivitySummary {
  ActivitySummary({
    required this.attemptedCount,
    required this.correctCount,
    required this.itemCount,
    required this.accuracy,
    required this.passed,
    required this.completionReason,
    required this.weakGroups,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      attemptedCount: (json['attempted_count'] as num).toInt(),
      correctCount: (json['correct_count'] as num).toInt(),
      itemCount: (json['item_count'] as num).toInt(),
      accuracy: (json['accuracy'] as num).toDouble(),
      passed: json['passed'] as bool,
      completionReason: json['completion_reason'] as String,
      weakGroups: (json['weak_groups'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
    );
  }

  final int attemptedCount;
  final int correctCount;
  final int itemCount;
  final double accuracy;
  final bool passed;
  final String completionReason;
  final List<String> weakGroups;
}
