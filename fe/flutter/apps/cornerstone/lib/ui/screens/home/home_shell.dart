part of '../../../main.dart';

enum _ShellDestination {
  owner('Learners', 'Students, sessions, and progress.', CornerstoneIcons.team),
  learner(
    'My work',
    'Current pathway and session work.',
    CornerstoneIcons.learning,
  ),
  library(
    'Library',
    'Pathways, sessions, and learning materials.',
    CornerstoneIcons.library,
  ),
  account(
    'Profile',
    'Profile, theme, and personal settings.',
    CornerstoneIcons.profile,
  );

  const _ShellDestination(this.label, this.subtitle, this.icon);
  final String label;
  final String subtitle;
  final IconData icon;
}

class CornerstoneHomePage extends StatefulWidget {
  const CornerstoneHomePage({
    required this.themeController,
    this.apiClient,
    super.key,
  });
  final CornerstoneApiClient? apiClient;
  final CornerstoneThemeController themeController;
  @override
  State<CornerstoneHomePage> createState() => _CornerstoneHomePageState();
}

class _CornerstoneHomePageState extends State<CornerstoneHomePage> {
  late final CornerstoneApiClient _apiClient =
      widget.apiClient ?? CornerstoneApiClient();
  ActivityPackageRun? _openPackageRun;
  final _activityKey = GlobalKey<ActivityPackagePageState>();
  ViewerSessionPayload? _viewerSession;
  DashboardPayload? _dashboard;
  LibraryWorkspacePayload? _libraryWorkspace;
  LibraryDocumentsPayload? _libraryDocuments;
  LibraryDocumentData? _selectedLibraryDocument;
  LearnerDetailPayload? _learnerDetail;
  LearnerWorkspacePayload? _learnerWorkspace;
  String? _selectedLearnerId;
  String? _requestedAssignmentId;
  String? _selectedLibraryRoutePath;
  String? _requestedLibraryPreviewRoute;
  _ShellDestination _selectedDestination = _ShellDestination.library;
  int _loadGeneration = 0;
  bool _shellNavExpanded = false;
  bool _profileMenuOpen = false;
  bool _sessionLoading = true;
  bool _loading = true;
  bool _authBusy = false;
  bool _busy = false;
  bool _libraryDocumentBusy = false;
  String? _sessionErrorMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreViewerSession();
  }

  ViewerUser? get _currentViewer => _viewerSession?.authenticatedUser;
  ViewerUser? get _activeViewer => _viewerSession?.activeUser ?? _currentViewer;
  List<TeamInfo> get _availableTeams =>
      _viewerSession?.availableTeams ?? const <TeamInfo>[];
  bool get _viewerCanManage => _activeViewer?.canManageTeam ?? false;
  bool get _viewerCanReadLibrary => _activeViewer?.canReadLibrary ?? false;
  bool get _viewerCanOpenDeveloperDocs =>
      _activeViewer?.canOpenDeveloperDocs ?? false;
  String? get _developerDocsUrl => _viewerSession?.developerDocsUrl;
  bool get _googleSigninEnabled => _viewerSession?.auth.googleSignin ?? false;

  List<_ShellDestination> get _availableDestinations {
    final viewer = _activeViewer;
    if (viewer == null) return const <_ShellDestination>[];
    if (viewer.canManageTeam) {
      return <_ShellDestination>[
        if (viewer.canReadLibrary) _ShellDestination.library,
        _ShellDestination.owner,
        _ShellDestination.learner,
        _ShellDestination.account,
      ];
    }
    return const <_ShellDestination>[
      _ShellDestination.learner,
      _ShellDestination.account,
    ];
  }

  List<LearnerDashboard> get _visibleLearners {
    final dashboard = _dashboard;
    final viewer = _activeViewer;
    if (dashboard == null) return const <LearnerDashboard>[];
    if (viewer == null ||
        viewer.canViewAllLearners ||
        viewer.learnerId == null) {
      return dashboard.learners;
    }
    return dashboard.learners
        .where((learner) => learner.learnerId == viewer.learnerId)
        .toList(growable: false);
  }

  _ShellDestination _defaultDestinationForViewer(ViewerUser viewer) {
    return viewer.isLearner || viewer.learnerId != null
        ? _ShellDestination.learner
        : viewer.canReadLibrary
        ? _ShellDestination.library
        : _ShellDestination.owner;
  }

  String? _nextLearnerIdForViewer(
    DashboardPayload dashboard, {
    bool preserveSelection = true,
  }) {
    final activeViewer = _activeViewer;
    if (activeViewer != null && activeViewer.learnerId != null) {
      final learnerId = activeViewer.learnerId!;
      return dashboard.learners.any((learner) => learner.learnerId == learnerId)
          ? learnerId
          : null;
    }
    if (preserveSelection && _selectedLearnerId != null) {
      final learnerId = _selectedLearnerId!;
      if (dashboard.learners.any((learner) => learner.learnerId == learnerId)) {
        return learnerId;
      }
    }
    return dashboard.learners.isNotEmpty
        ? dashboard.learners.first.learnerId
        : null;
  }

  String? _authErrorMessageFromLocation() {
    final code = Uri.base.queryParameters['auth_error']?.trim();
    if (code == null || code.isEmpty) {
      return null;
    }
    return switch (code) {
      'access_denied' => 'Google sign-in was cancelled or denied.',
      'missing_state' => 'Google sign-in could not be completed.',
      'missing_code' => 'Google sign-in did not return an authorization code.',
      _ => 'Google sign-in failed: $code',
    };
  }

  Future<void> _restoreViewerSession() async {
    setState(() {
      _sessionLoading = true;
      _sessionErrorMessage = null;
    });
    try {
      final viewerSession = await _apiClient.fetchViewerSession();
      if (!mounted) return;
      final authErrorMessage = viewerSession.authenticatedUser == null
          ? _authErrorMessageFromLocation()
          : null;

      if (viewerSession.authenticatedUser == null) {
        setState(() {
          _viewerSession = viewerSession;
          _sessionLoading = false;
          _authBusy = false;
          _sessionErrorMessage = authErrorMessage;
          _dashboard = null;
          _libraryWorkspace = null;
          _libraryDocuments = null;
          _selectedLibraryDocument = null;
          _learnerDetail = null;
          _selectedLearnerId = null;
          _selectedLibraryRoutePath = null;
          _selectedDestination = _ShellDestination.owner;
          _loading = false;
          _busy = false;
          _libraryDocumentBusy = false;
          _errorMessage = null;
        });
        return;
      }

      final defaultViewer =
          viewerSession.activeUser ?? viewerSession.authenticatedUser!;
      setState(() {
        _viewerSession = viewerSession;
        _sessionLoading = false;
        _authBusy = false;
        _sessionErrorMessage = null;
        _dashboard = null;
        _libraryWorkspace = null;
        _libraryDocuments = null;
        _selectedLibraryDocument = null;
        _learnerDetail = null;
        _learnerWorkspace = null;
        _selectedLearnerId = null;
        _selectedLibraryRoutePath = null;
        _selectedDestination = _defaultDestinationForViewer(defaultViewer);
        _loading = true;
        _busy = false;
        _libraryDocumentBusy = false;
        _errorMessage = null;
      });
      await _loadAll(preserveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionLoading = false;
        _authBusy = false;
        _loading = false;
        _busy = false;
        _sessionErrorMessage = error.toString();
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _authBusy = true;
      _sessionErrorMessage = null;
    });
    final launched = await launchUrl(
      _apiClient.googleStartUri(),
      webOnlyWindowName: '_self',
    );
    if (!launched && mounted) {
      setState(() {
        _authBusy = false;
        _sessionErrorMessage = 'Unable to start Google sign-in.';
      });
    }
  }

  Future<void> _switchActiveUser(
    String userId, {
    String? preferredLearnerId,
    _ShellDestination? destination,
  }) async {
    if (!await _leaveActivity() || !mounted) return;
    _loadGeneration++;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _sessionErrorMessage = null;
    });
    try {
      final viewerSession = await _apiClient.switchActiveUser(userId);
      if (!mounted) return;
      final activeUser =
          viewerSession.activeUser ?? viewerSession.authenticatedUser;
      setState(() {
        _viewerSession = viewerSession;
        _selectedLearnerId = preferredLearnerId ?? activeUser?.learnerId;
        if (destination != null) {
          _selectedDestination = destination;
        }
      });
      await _loadAll(preserveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _switchActiveTeam(String teamId) async {
    if (!await _leaveActivity() || !mounted) return;
    _loadGeneration++;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _sessionErrorMessage = null;
    });
    try {
      final viewerSession = await _apiClient.switchActiveTeam(teamId);
      if (!mounted) return;
      final activeUser =
          viewerSession.activeUser ?? viewerSession.authenticatedUser;
      final destination = activeUser == null
          ? _ShellDestination.account
          : _defaultDestinationForViewer(activeUser);
      setState(() {
        _viewerSession = viewerSession;
        _selectedLearnerId = activeUser?.learnerId;
        _selectedDestination = destination;
      });
      await _loadAll(preserveSelection: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _logoutViewer() async {
    if (!await _leaveActivity() || !mounted) return;
    _loadGeneration++;
    setState(() {
      _authBusy = true;
      _sessionErrorMessage = null;
    });
    try {
      await _apiClient.logout();
      if (!mounted) return;
      await _restoreViewerSession();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authBusy = false;
        _sessionErrorMessage = error.toString();
      });
    }
  }

  Future<void> _loadAll({bool preserveSelection = true}) async {
    final generation = ++_loadGeneration;
    if (_currentViewer == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = _dashboard == null;
      _busy = true;
      _errorMessage = null;
    });
    try {
      final dashboard = await _apiClient.fetchDashboard();
      if (!mounted || generation != _loadGeneration) return;
      final nextLearnerId = _nextLearnerIdForViewer(
        dashboard,
        preserveSelection: preserveSelection,
      );
      LibraryWorkspacePayload? libraryWorkspace;
      LibraryDocumentsPayload? libraryDocuments;
      String? nextLibraryRoutePath;
      LearnerDetailPayload? learnerDetail;
      LearnerWorkspacePayload? learnerWorkspace;
      LibraryDocumentData? selectedLibraryDocument;
      if (nextLearnerId != null) {
        if (_viewerCanManage) {
          final results = await Future.wait<dynamic>([
            _apiClient.fetchLearnerDetail(nextLearnerId),
            _apiClient.fetchLearnerWorkspace(nextLearnerId),
          ]);
          learnerDetail = results[0] as LearnerDetailPayload;
          learnerWorkspace = results[1] as LearnerWorkspacePayload;
        } else {
          learnerWorkspace = await _apiClient.fetchLearnerWorkspace(
            nextLearnerId,
          );
        }
      }
      if (_viewerCanReadLibrary) {
        libraryWorkspace = await _apiClient.fetchLibraryWorkspace();
        libraryDocuments = await _apiClient.fetchLibraryDocuments();
        nextLibraryRoutePath = _nextLibraryRoutePath(
          libraryWorkspace: libraryWorkspace,
          documents: libraryDocuments,
          preserveSelection: preserveSelection,
        );
      }
      if (nextLibraryRoutePath != null) {
        selectedLibraryDocument = await _apiClient.fetchLibraryDocument(
          nextLibraryRoutePath,
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _dashboard = dashboard;
        _libraryWorkspace = libraryWorkspace;
        _libraryDocuments = libraryDocuments;
        _selectedLibraryRoutePath = nextLibraryRoutePath;
        _selectedLibraryDocument = selectedLibraryDocument;
        _selectedLearnerId = nextLearnerId;
        _learnerDetail = learnerDetail;
        _learnerWorkspace = learnerWorkspace;
        _loading = false;
        _busy = false;
        _libraryDocumentBusy = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  String? _nextLibraryRoutePath({
    required LibraryWorkspacePayload libraryWorkspace,
    required LibraryDocumentsPayload documents,
    bool preserveSelection = true,
  }) {
    final availableRoutes = documents.documents
        .map((document) => document.routePath)
        .toSet();
    if (preserveSelection &&
        _selectedLibraryRoutePath != null &&
        availableRoutes.contains(_selectedLibraryRoutePath)) {
      return _selectedLibraryRoutePath;
    }

    final featuredRoutePath = libraryWorkspace.featuredRoutePath;
    if (featuredRoutePath != null &&
        availableRoutes.contains(featuredRoutePath)) {
      return featuredRoutePath;
    }

    for (final pathway in libraryWorkspace.pathways) {
      if (pathway.routePath != null &&
          availableRoutes.contains(pathway.routePath)) {
        return pathway.routePath;
      }
      for (final playlist in pathway.playlists) {
        if (playlist.routePath != null &&
            availableRoutes.contains(playlist.routePath)) {
          return playlist.routePath;
        }
        for (final session in playlist.sessions) {
          for (final material in session.materials) {
            if (material.routePath != null &&
                availableRoutes.contains(material.routePath)) {
              return material.routePath;
            }
          }
        }
      }
    }

    return documents.documents.isNotEmpty
        ? documents.documents.first.routePath
        : null;
  }

  Future<void> _openLibraryDocumentFromWork(String routePath) async {
    setState(() => _requestedLibraryPreviewRoute = routePath);
    await _selectLibraryDocument(routePath);
  }

  Future<void> _selectLibraryDocument(String routePath) async {
    if (!_viewerCanReadLibrary) {
      return;
    }
    final normalizedRoutePath = routePath.trim().replaceAll(
      RegExp(r'^/+|/+$'),
      '',
    );
    if (normalizedRoutePath.isEmpty) {
      return;
    }
    if (normalizedRoutePath == _selectedLibraryRoutePath &&
        _selectedLibraryDocument != null) {
      _setDestination(_ShellDestination.library);
      return;
    }

    setState(() {
      _selectedDestination = _ShellDestination.library;
      _selectedLibraryRoutePath = normalizedRoutePath;
      _libraryDocumentBusy = true;
    });

    try {
      final document = await _apiClient.fetchLibraryDocument(
        normalizedRoutePath,
      );
      if (!mounted || _selectedLibraryRoutePath != normalizedRoutePath) return;
      setState(() {
        _selectedLibraryDocument = document;
        _libraryDocumentBusy = false;
      });
    } catch (error) {
      if (!mounted || _selectedLibraryRoutePath != normalizedRoutePath) return;
      setState(() {
        _libraryDocumentBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load that document: $error')),
      );
    }
  }

  Future<void> _selectLearner(String learnerId) async {
    final viewer = _activeViewer;
    if (viewer != null && viewer.isLearner && viewer.learnerId != learnerId) {
      return;
    }
    setState(() {
      _selectedLearnerId = learnerId;
      _busy = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _apiClient.fetchLearnerDetail(learnerId),
        _apiClient.fetchLearnerWorkspace(learnerId),
      ]);
      if (!mounted || _selectedLearnerId != learnerId) return;
      setState(() {
        _learnerDetail = results[0] as LearnerDetailPayload;
        _learnerWorkspace = results[1] as LearnerWorkspacePayload;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || _selectedLearnerId != learnerId) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _showAssignment({
    required String title,
    required List<PlaylistAssignmentTarget> targets,
    required String playlistId,
  }) async {
    if (!_viewerCanManage) return;
    final selection = await showDialog<AssignmentSelection>(
      context: context,
      builder: (_) => AssignMaterialDialog(title: title, targets: targets),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _apiClient.createAssignment(
        learnerId: selection.learnerId,
        playlistId: playlistId,
      );
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Assigned $title.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _recordPaperSession(SessionDetail session) async {
    if (!_viewerCanManage) return;
    final score = TextEditingController();
    final maximum = TextEditingController(text: '10');
    final minutes = TextEditingController(text: '10');
    final notes = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record paper result'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: score,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Correct answers',
                    ),
                    validator: (value) {
                      final n = double.tryParse(value ?? '');
                      final max = double.tryParse(maximum.text);
                      return n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              max == null ||
                              n > max
                          ? 'Enter a score between zero and the total.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: maximum,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total questions',
                    ),
                    validator: (value) {
                      final n = double.tryParse(value ?? '');
                      return n == null || !n.isFinite || n <= 0
                          ? 'Enter a positive total.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Time in minutes',
                    ),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Enter the time taken.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save result'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _busy = true;
        _errorMessage = null;
      });
      try {
        await _apiClient.recordSession(
          sessionId: session.sessionId,
          score: double.parse(score.text),
          maxScore: double.parse(maximum.text),
          durationMinutes: int.parse(minutes.text),
          notes: notes.text.trim(),
        );
        await _loadAll();
      } catch (error) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorMessage = error.toString();
          });
        }
      }
    }
    // Wait for the dialog's exit animation before disposing its field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    score.dispose();
    maximum.dispose();
    minutes.dispose();
    notes.dispose();
  }

  Future<void> _startActivityForMaterial(
    SessionDetail session,
    SessionMaterial material,
  ) async {
    if (!material.canStartActivity) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final activity = await _apiClient.startSessionMaterialActivity(
        sessionId: session.sessionId,
        sessionMaterialId: material.sessionMaterialId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      await _openExecutableActivity(activity);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _openExecutableActivity(ActivityInstance activity) async {
    final presentation = activity.presentation;
    if (presentation != null) {
      setState(() => _openPackageRun = _packageRun(activity));
      return;
    }
    throw StateError('The activity has no presentation package.');
  }

  ActivityPackageRun _packageRun(ActivityInstance activity) =>
      ActivityPackageRun(
        id: activity.activityInstanceId,
        title: activity.materialTitle,
        presentation: activity.presentation!,
        onCheck: (responses, _) => _apiClient.checkPackageActivity(
          activity.activityInstanceId,
          responses,
        ),
        onComplete: (responses, duration) => _apiClient.completePackageActivity(
          activity.activityInstanceId,
          responses,
          duration,
        ),
        onRetry: () async => _packageRun(
          await _apiClient.retryActivity(activity.activityInstanceId),
        ),
      );

  Future<void> _startReviewItem(ReviewItem reviewItem) async {
    if (reviewItem.reviewStatus != ReviewStatus.due) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final activity = await _apiClient.startReviewItem(
        reviewItem.reviewItemId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      await _openExecutableActivity(activity);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _setReadinessOverrideForMaterial(
    SessionMaterial material,
  ) async {
    if (!_viewerCanManage) return;
    final learnerId =
        _selectedLearnerId ?? _learnerWorkspace?.learner.learnerId;
    final readiness = material.readiness;
    if (learnerId == null || readiness == null) return;
    final minimumRunsController = TextEditingController(
      text: readiness.minimumRuns.toString(),
    );
    final recentRunWindowController = TextEditingController(
      text: readiness.recentRunWindow.toString(),
    );
    final targetAccuracyController = TextEditingController(
      text: (readiness.targetAccuracy * 100).round().toString(),
    );
    final consecutiveController = TextEditingController(
      text: readiness.consecutiveTargetRunsRequired.toString(),
    );
    final targetCorrectController = TextEditingController(
      text: readiness.targetCorrectCount?.toString() ?? '',
    );
    final minimumDistinctItemsController = TextEditingController(
      text: readiness.minimumDistinctItems.toString(),
    );
    final minimumFamilyCountController = TextEditingController(
      text: readiness.minimumFamilyCount.toString(),
    );
    final maxDurationController = TextEditingController(
      text: readiness.maxDurationSeconds?.toString() ?? '',
    );
    final reasonController = TextEditingController(
      text: readiness.overrideReason,
    );

    try {
      final request = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (context) {
          String? errorMessage;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              int? optionalInt(String value) {
                final trimmed = value.trim();
                return trimmed.isEmpty ? null : int.tryParse(trimmed);
              }

              return AlertDialog(
                title: Text('Custom target for ${material.title}'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: minimumRunsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum runs',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: recentRunWindowController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Recent run window',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: targetAccuracyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Target accuracy percent',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: consecutiveController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Consecutive target runs',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: targetCorrectController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Target correct count',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: minimumDistinctItemsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum distinct facts',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: minimumFamilyCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum fact families',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: maxDurationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max seconds (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final minimumRuns = int.tryParse(
                        minimumRunsController.text.trim(),
                      );
                      final recentRunWindow = int.tryParse(
                        recentRunWindowController.text.trim(),
                      );
                      final targetAccuracyPercent = int.tryParse(
                        targetAccuracyController.text.trim(),
                      );
                      final consecutiveTargetRunsRequired = int.tryParse(
                        consecutiveController.text.trim(),
                      );
                      final targetCorrectCount = optionalInt(
                        targetCorrectController.text,
                      );
                      final minimumDistinctItems = int.tryParse(
                        minimumDistinctItemsController.text.trim(),
                      );
                      final minimumFamilyCount = int.tryParse(
                        minimumFamilyCountController.text.trim(),
                      );
                      final maxDurationSeconds = optionalInt(
                        maxDurationController.text,
                      );
                      final invalid =
                          minimumRuns == null ||
                          minimumRuns <= 0 ||
                          recentRunWindow == null ||
                          recentRunWindow <= 0 ||
                          targetAccuracyPercent == null ||
                          targetAccuracyPercent <= 0 ||
                          targetAccuracyPercent > 100 ||
                          consecutiveTargetRunsRequired == null ||
                          consecutiveTargetRunsRequired <= 0 ||
                          minimumDistinctItems == null ||
                          minimumDistinctItems <= 0 ||
                          minimumFamilyCount == null ||
                          minimumFamilyCount <= 0 ||
                          (targetCorrectCount != null &&
                              targetCorrectCount <= 0) ||
                          (maxDurationSeconds != null &&
                              maxDurationSeconds <= 0);
                      if (invalid) {
                        setDialogState(() {
                          errorMessage =
                              'Use positive numbers; accuracy must be 1-100.';
                        });
                        return;
                      }
                      Navigator.of(context).pop(<String, Object?>{
                        'minimumRuns': minimumRuns,
                        'recentRunWindow': recentRunWindow,
                        'targetAccuracy':
                            targetAccuracyPercent.toDouble() / 100,
                        'consecutiveTargetRunsRequired':
                            consecutiveTargetRunsRequired,
                        'targetCorrectCount': targetCorrectCount,
                        'minimumDistinctItems': minimumDistinctItems,
                        'minimumFamilyCount': minimumFamilyCount,
                        'maxDurationSeconds': maxDurationSeconds,
                        'reason': reasonController.text.trim(),
                      });
                    },
                    child: const Text('Save target'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (request == null) return;
      setState(() {
        _busy = true;
        _errorMessage = null;
      });
      await _apiClient.setReadinessOverride(
        learnerId: learnerId,
        materialId: material.materialId,
        minimumRuns: request['minimumRuns']! as int,
        recentRunWindow: request['recentRunWindow']! as int,
        targetAccuracy: request['targetAccuracy']! as double,
        consecutiveTargetRunsRequired:
            request['consecutiveTargetRunsRequired']! as int,
        targetCorrectCount: request['targetCorrectCount'] as int?,
        minimumDistinctItems: request['minimumDistinctItems']! as int,
        minimumFamilyCount: request['minimumFamilyCount']! as int,
        maxDurationSeconds: request['maxDurationSeconds'] as int?,
        reason: request['reason']! as String,
      );
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    } finally {
      minimumRunsController.dispose();
      recentRunWindowController.dispose();
      targetAccuracyController.dispose();
      consecutiveController.dispose();
      targetCorrectController.dispose();
      minimumDistinctItemsController.dispose();
      minimumFamilyCountController.dispose();
      maxDurationController.dispose();
      reasonController.dispose();
    }
  }

  Future<void> _clearReadinessOverrideForMaterial(
    SessionMaterial material,
  ) async {
    if (!_viewerCanManage) return;
    final learnerId =
        _selectedLearnerId ?? _learnerWorkspace?.learner.learnerId;
    if (learnerId == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _apiClient.clearReadinessOverride(
        learnerId: learnerId,
        materialId: material.materialId,
      );
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  String _destinationLabel(_ShellDestination destination) =>
      destination == _ShellDestination.learner && _viewerCanManage
      ? 'Student work'
      : destination.label;

  Future<bool> _leaveActivity() async {
    if (_openPackageRun == null) return true;
    return await _activityKey.currentState?.requestClose() ?? false;
  }

  Future<void> _setDestination(_ShellDestination d) async {
    if (!_availableDestinations.contains(d)) return;
    if (_openPackageRun != null) {
      final leave = await _activityKey.currentState?.requestClose();
      if (leave != true || !mounted) return;
    }
    setState(() => _selectedDestination = d);
  }

  void _toggleShellNavigation() =>
      setState(() => _shellNavExpanded = !_shellNavExpanded);

  String _shellUsername() =>
      _activeViewer?.displayName ??
      _currentViewer?.displayName ??
      _viewerSession?.team?.displayName ??
      'Cornerstone';

  String _viewerRoleLabel(ViewerUser? viewer) {
    if (viewer == null) return 'Signed out';
    if (viewer.canOpenDeveloperDocs) return 'Owner';
    return viewer.canManageTeam ? 'Owner' : 'Learner';
  }

  String _shellWorkspaceLabel() {
    final viewer = _currentViewer;
    if (viewer == null) return 'Signed out';
    final activeViewer = _activeViewer;
    if (activeViewer != null && activeViewer.userId != viewer.userId) {
      return 'Viewing ${activeViewer.displayName}';
    }
    return viewer.canManageTeam ? 'Team' : 'Learner';
  }

  String _shellTeamName() =>
      _viewerSession?.team?.displayName ?? 'Cornerstone Team';

  bool _hasMeaningfulViewerNotes(ViewerUser viewer) {
    final notes = viewer.notes.trim();
    return notes.isNotEmpty && notes.toLowerCase() != 'owner';
  }

  double _contentMaxWidthFor(_ShellDestination destination) {
    return switch (destination) {
      _ShellDestination.owner => 1240,
      _ShellDestination.learner => 1240,
      _ShellDestination.library => 1320,
      _ShellDestination.account => 1080,
    };
  }

  Widget _wrapMainContent(Widget child, {double? maxWidth}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? _contentMaxWidthFor(_selectedDestination),
        ),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  String _identityInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CO';
    if (parts.length == 1) {
      final w = parts.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildViewerAvatar(
    ViewerUser? viewer, {
    required double size,
    bool selected = false,
    bool useGoogleProfile = true,
    TextStyle? initialsStyle,
    bool brandedInitials = false,
  }) {
    final theme = Theme.of(context);
    final label = viewer == null
        ? 'Cornerstone'
        : useGoogleProfile
        ? viewer.profileLabel
        : viewer.displayName;
    final pictureUrl = useGoogleProfile ? viewer?.profilePictureUrl : null;
    final initials = _identityInitials(label);
    final borderColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.30)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.50);

    if (pictureUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          pictureUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildViewerInitialsAvatar(
              size: size,
              selected: selected,
              brandedInitials: brandedInitials,
              initialsStyle: initialsStyle,
              initials: initials,
            );
          },
        ),
      );
    }

    return _buildViewerInitialsAvatar(
      size: size,
      selected: selected,
      brandedInitials: brandedInitials,
      initialsStyle: initialsStyle,
      initials: initials,
    );
  }

  Widget _buildViewerInitialsAvatar({
    required double size,
    required bool selected,
    required bool brandedInitials,
    required String initials,
    TextStyle? initialsStyle,
  }) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: selected
          ? theme.colorScheme.onPrimary
          : brandedInitials
          ? _BrandPalette.navy
          : theme.colorScheme.onSurfaceVariant,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected || brandedInitials
            ? const LinearGradient(
                colors: [_BrandPalette.goldBright, _BrandPalette.goldDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected || brandedInitials
            ? null
            : theme.colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.30)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.50),
          width: selected ? 1.5 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: initialsStyle ?? defaultStyle),
    );
  }

  Future<void> _openDeveloperDocs() async {
    final rawUrl = _developerDocsUrl;
    final docsUri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (docsUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Developer docs are not configured for this environment.',
          ),
        ),
      );
      return;
    }
    final launched = await launchUrl(docsUri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open developer docs at $rawUrl')),
      );
    }
  }

  List<Widget> _buildProfileMenuChildren(BuildContext context) {
    final children = <Widget>[
      MenuItemButton(
        leadingIcon: const Icon(CornerstoneIcons.profile),
        onPressed: () => _setDestination(_ShellDestination.account),
        child: const Text('My Account'),
      ),
    ];
    if (_viewerCanReadLibrary && !_viewerCanOpenDeveloperDocs) {
      children.add(
        MenuItemButton(
          leadingIcon: const Icon(CornerstoneIcons.library),
          onPressed: () => _setDestination(_ShellDestination.library),
          child: const Text('Open pathway library'),
        ),
      );
    }
    if (_viewerCanOpenDeveloperDocs &&
        (_developerDocsUrl?.isNotEmpty ?? false)) {
      children.add(
        MenuItemButton(
          leadingIcon: const Icon(Icons.developer_mode_rounded),
          onPressed: () => _openDeveloperDocs(),
          child: const Text('Open developer docs'),
        ),
      );
    }
    children.addAll([
      MenuItemButton(
        leadingIcon: const Icon(Icons.logout_rounded),
        onPressed: _authBusy ? null : () => _logoutViewer(),
        child: const Text('Log out'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Divider(height: 18),
      ),
      SizedBox(
        width: 284,
        child: _AppearancePanel(
          controller: widget.themeController,
          compact: true,
        ),
      ),
    ]);
    return children;
  }

  Widget _buildProfileMenuAnchor({required bool compact}) {
    final theme = Theme.of(context);
    final selected = _selectedDestination == _ShellDestination.account;
    final username = _shellUsername();
    final authenticatedViewer = _currentViewer;
    final avatarSize = compact ? 40.0 : 36.0;
    final avatar = _buildViewerAvatar(
      authenticatedViewer,
      size: avatarSize,
      selected: selected && authenticatedViewer?.profilePictureUrl == null,
      useGoogleProfile: true,
    );

    return Tooltip(
      message: username,
      child: _HoverProfileMenu(
        onOpenChanged: (open) {
          if (mounted) setState(() => _profileMenuOpen = open);
        },
        items: _buildProfileMenuChildren(context),
        child: compact
            ? avatar
            : Row(
                children: [
                  avatar,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          username,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          _shellWorkspaceLabel(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShellRailToggle(ThemeData theme) {
    return Tooltip(
      message: _shellNavExpanded ? 'Collapse navigation' : 'Expand navigation',
      child: IconButton(
        onPressed: _toggleShellNavigation,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          _shellNavExpanded
              ? Icons.keyboard_double_arrow_left_rounded
              : Icons.keyboard_double_arrow_right_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildShellHeader(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
    child: Row(
      children: [
        if (_shellNavExpanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_shellTeamName(), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _viewerCanManage ? 'Owner workspace' : 'Learning space',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        _buildShellRailToggle(theme),
      ],
    ),
  );

  Widget _buildDesktopNavItem(
    BuildContext context,
    _ShellDestination destination,
  ) {
    final theme = Theme.of(context);
    final selected = _selectedDestination == destination;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: _destinationLabel(destination),
        child: !_shellNavExpanded
            ? IconButton(
                tooltip: _destinationLabel(destination),
                onPressed: () => _setDestination(destination),
                style: IconButton.styleFrom(
                  backgroundColor: selected
                      ? theme.colorScheme.primaryContainer
                      : Colors.transparent,
                ),
                icon: Icon(destination.icon, size: 21),
              )
            : ListTile(
                selected: selected,
                dense: true,
                selectedTileColor: theme.colorScheme.primaryContainer,
                leading: Icon(destination.icon, size: 21),
                title: _shellNavExpanded
                    ? Text(
                        _destinationLabel(destination),
                        style: theme.textTheme.labelLarge,
                      )
                    : null,
                onTap: () => _setDestination(destination),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _shellNavExpanded ? 14 : 10,
                  vertical: 0,
                ),
              ),
      ),
    );
  }

  Widget _buildDesktopShell(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Container(
      width: _shellNavExpanded ? 188 : 68,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildShellHeader(Theme.of(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _availableDestinations
                  .map((d) => _buildDesktopNavItem(context, d))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: _buildProfileMenuAnchor(compact: !_shellNavExpanded),
          ),
        ],
      ),
    ),
  );

  Widget _buildMobileDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = _shellUsername();
    return Drawer(
      backgroundColor: isDark
          ? _BrandPalette.slatePanel
          : _BrandPalette.warmPaper,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [_BrandPalette.slateRaised, _BrandPalette.slateCard]
                      : [Colors.white, _BrandPalette.warmPaper],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  _buildViewerAvatar(
                    _currentViewer,
                    size: 48,
                    brandedInitials: _currentViewer?.profilePictureUrl == null,
                    initialsStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _BrandPalette.navy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEAM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          username,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shellWorkspaceLabel(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'VIEWS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ..._availableDestinations.map(
              (d) => ListTile(
                leading: Icon(d.icon),
                title: Text(_destinationLabel(d)),
                subtitle: Text(
                  d.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _selectedDestination == d,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _setDestination(d);
                },
              ),
            ),
            if (_viewerCanOpenDeveloperDocs &&
                (_developerDocsUrl?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.developer_mode_rounded),
                title: const Text('Developer Docs'),
                subtitle: const Text(
                  'Open the standalone developer documentation site.',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _openDeveloperDocs();
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: _authBusy
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _logoutViewer();
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentViewer == null) {
      return _buildSignedOutScaffold(context);
    }

    final isMobile = MediaQuery.sizeOf(context).width < 960;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 14,
        title: _BrandLockup(
          compact: isMobile,
          toolbarVariant: true,
          onTap: () =>
              _setDestination(_defaultDestinationForViewer(_activeViewer!)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.0),
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_busy || _authBusy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (isMobile) _buildProfileMenuAnchor(compact: true),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isMobile ? _buildMobileDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile) _buildDesktopShell(context),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset =
                    Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_selectedDestination),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Offstage(
                      offstage: _openPackageRun != null,
                      child: ExcludeFocus(
                        excluding: _openPackageRun != null,
                        child: Column(
                          children: [
                            if (_viewerCanManage &&
                                _selectedDestination ==
                                    _ShellDestination.learner)
                              _buildLearnerContext(),
                            Expanded(child: _buildContentBody(context)),
                          ],
                        ),
                      ),
                    ),
                    if (_openPackageRun != null)
                      Positioned.fill(
                        child: _wrapMainContent(
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: ActivityPackagePage(
                              key: _activityKey,
                              run: _openPackageRun!,
                              interactionEnabled: !_profileMenuOpen,
                              apiBaseUrl: _apiClient.baseUrl,
                              onClose: (_) {
                                setState(() => _openPackageRun = null);
                                _loadAll();
                              },
                            ),
                          ),
                          maxWidth: 1280,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnerContext() => _wrapMainContent(
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 18),
          const SizedBox(width: 10),
          const Text('Viewing work for'),
          const SizedBox(width: 12),
          Flexible(
            child: DropdownButton<String>(
              value: _selectedLearnerId,
              isExpanded: false,
              items: _visibleLearners
                  .map(
                    (learner) => DropdownMenuItem(
                      value: learner.learnerId,
                      child: Text(learner.displayName),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (id) {
                      if (id != null) _selectLearner(id);
                    },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildOwnerView(
    BuildContext context,
    DashboardPayload dashboard,
    LibraryWorkspacePayload libraryWorkspace,
  ) {
    return _OwnerWorkspaceView(
      learners: _visibleLearners,
      selectedLearnerId: _selectedLearnerId,
      detail: _learnerDetail,
      onSelectLearner: _selectLearner,
      onOpenLearning: () => _setDestination(_ShellDestination.learner),
      onOpenAssignment: (id) {
        setState(() => _requestedAssignmentId = id);
        _setDestination(_ShellDestination.learner);
      },
      onOpenLibrary: () => _setDestination(_ShellDestination.library),
      onStartReview: _startReviewItem,
    );
  }

  Widget _buildLearnerView(BuildContext context) {
    return LearnerWorkspaceView(
      viewer: _activeViewer,
      workspace: _learnerWorkspace,
      initialAssignmentId: _requestedAssignmentId,
      onInitialAssignmentHandled: () =>
          setState(() => _requestedAssignmentId = null),
      viewerCanReadLibrary: _viewerCanReadLibrary,
      onOpenLibraryRoute: _openLibraryDocumentFromWork,
      onStartActivity: _startActivityForMaterial,
      onStartReview: _startReviewItem,
      onCreateWorksheetForLevel: _openWorksheetLevel,
      onRecordPaperResult: _viewerCanManage ? _recordPaperSession : null,
      onSetReadinessOverride: _viewerCanManage
          ? _setReadinessOverrideForMaterial
          : null,
      onClearReadinessOverride: _viewerCanManage
          ? _clearReadinessOverrideForMaterial
          : null,
    );
  }

  Widget _buildLibraryView(
    BuildContext context,
    LibraryWorkspacePayload libraryWorkspace,
  ) {
    return MaterialsWorkspaceView(
      library: libraryWorkspace,
      documents: _libraryDocuments,
      activeDocument: _selectedLibraryDocument,
      requestedPreviewRoute: _requestedLibraryPreviewRoute,
      onPreviewRequestHandled: () => setState(() {
        _requestedLibraryPreviewRoute = null;
      }),
      documentBusy: _libraryDocumentBusy,
      canAssign: _viewerCanManage,
      onAssignPlaylist: (playlist) => _showAssignment(
        title: playlist.title,
        targets: playlist.assignmentTargets,
        playlistId: playlist.playlistId,
      ),
      onOpenDocument: _selectLibraryDocument,
      onCreateWorksheetForLevel: _openWorksheetLevel,
      onPreviewActivity: _previewMaterial,
    );
  }

  Future<void> _previewMaterial(LibraryWorkspaceMaterial material) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final preview = await _apiClient.previewMaterial(material.materialId);
      if (!mounted) return;
      Future<Map<String, dynamic>> submit(
        List<Map<String, String>> responses,
        int duration,
        bool finish,
      ) => _apiClient.submitPreview(
        materialId: material.materialId,
        seed: preview['seed'] as String,
        revision: preview['revision'] as String,
        responses: responses,
        duration: duration,
        finish: finish,
      );
      setState(
        () => _openPackageRun = ActivityPackageRun(
          id: 'preview-${preview['seed']}',
          title: '${material.title} · Owner preview',
          presentation: ActivityPresentation.fromJson(
            preview['presentation'] as Map<String, dynamic>,
          ),
          onCheck: (responses, duration) => submit(responses, duration, false),
          onComplete: (responses, duration) =>
              submit(responses, duration, true),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openWorksheetLevel(String levelId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WrittenArithmeticScreen(
        apiClient: _apiClient,
        canPrintAnswers: _viewerCanManage,
        initialLevelId: levelId,
      ),
    ),
  );
}
