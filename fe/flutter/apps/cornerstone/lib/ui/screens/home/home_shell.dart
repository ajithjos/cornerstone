part of '../../../main.dart';

enum _ShellDestination {
  owner('Team', 'Learners and sessions.', CornerstoneIcons.team),
  learner(
    'Learning',
    'Current pathway and session work.',
    CornerstoneIcons.learning,
  ),
  library(
    'Pathways',
    'Review authored routes, playlists, and materials.',
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
  const CornerstoneHomePage({required this.themeController, super.key});
  final CornerstoneThemeController themeController;
  @override
  State<CornerstoneHomePage> createState() => _CornerstoneHomePageState();
}

class _CornerstoneHomePageState extends State<CornerstoneHomePage> {
  final CornerstoneApiClient _apiClient = CornerstoneApiClient();
  final TextEditingController _scoreController = TextEditingController(
    text: '8',
  );
  final TextEditingController _maxScoreController = TextEditingController(
    text: '10',
  );
  final TextEditingController _durationController = TextEditingController(
    text: '15',
  );
  final TextEditingController _notesController = TextEditingController(
    text: 'Completed well with one or two slow facts.',
  );

  ViewerSessionPayload? _viewerSession;
  DashboardPayload? _dashboard;
  LibraryWorkspacePayload? _libraryWorkspace;
  LibraryDocumentsPayload? _libraryDocuments;
  LibraryDocumentData? _selectedLibraryDocument;
  LearnerDetailPayload? _learnerDetail;
  LearnerWorkspacePayload? _learnerWorkspace;
  String? _selectedLearnerId;
  String? _selectedLibraryRoutePath;
  _ShellDestination _selectedDestination = _ShellDestination.owner;
  bool _shellNavExpanded = true;
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

  @override
  void dispose() {
    _scoreController.dispose();
    _maxScoreController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
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
        _ShellDestination.owner,
        _ShellDestination.learner,
        if (viewer.canReadLibrary) _ShellDestination.library,
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
    if (_currentViewer == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final dashboard = await _apiClient.fetchDashboard();
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _selectedLibraryDocument = document;
        _libraryDocumentBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _libraryDocumentBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load that document: $error')),
      );
    }
  }

  Future<void> _selectLearner(String learnerId) async {
    final viewer = _currentViewer;
    if (viewer != null && viewer.isLearner && viewer.learnerId != learnerId) {
      return;
    }
    final activeViewer = _activeViewer;
    if (viewer != null &&
        viewer.canManageTeam &&
        activeViewer?.learnerId != learnerId) {
      await _switchActiveUser(
        learnerId,
        preferredLearnerId: learnerId,
        destination: _selectedDestination,
      );
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
      if (!mounted) return;
      setState(() {
        _learnerDetail = results[0] as LearnerDetailPayload;
        _learnerWorkspace = results[1] as LearnerWorkspacePayload;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _createAssignment(String learnerId, String playlistId) async {
    if (!_viewerCanManage) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _apiClient.createAssignment(
        learnerId: learnerId,
        playlistId: playlistId,
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

  Future<void> _recordCurrentSession() async {
    if (!_viewerCanManage) return;
    final session = _currentActionSession;
    if (session == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _apiClient.recordSession(
        sessionId: session.sessionId,
        score: double.parse(_scoreController.text),
        maxScore: double.parse(_maxScoreController.text),
        durationMinutes: int.parse(_durationController.text),
        notes: _notesController.text,
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
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ExecutableActivityDialog(
          activity: activity,
          onComplete: (answers, durationSeconds, notes) =>
              _completeExecutableActivity(
                activity,
                answers,
                durationSeconds,
                notes,
              ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<CompleteActivityResponse> _completeExecutableActivity(
    ActivityInstance activity,
    List<String> answers,
    int durationSeconds,
    String notes,
  ) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiClient.completeActivity(
        activityInstanceId: activity.activityInstanceId,
        answers: answers,
        items: activity.items,
        durationSeconds: durationSeconds,
        notes: notes,
      );
      await _loadAll();
      return response;
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage = error.toString();
        });
      }
      rethrow;
    }
  }

  SessionDetail? get _currentActionSession {
    final detail = _learnerDetail;
    if (detail == null) return null;
    for (final session in detail.sessions) {
      if (session.status != 'completed') return session;
    }
    return null;
  }

  void _setDestination(_ShellDestination d) {
    if (!_availableDestinations.contains(d)) return;
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
      _ShellDestination.owner => 1460,
      _ShellDestination.learner => 1360,
      _ShellDestination.library => 1780,
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

    return MenuAnchor(
      menuChildren: _buildProfileMenuChildren(context),
      builder: (context, controller, _) {
        if (compact) {
          return Tooltip(
            message: username,
            child: IconButton(
              tooltip: 'Profile menu',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: avatar,
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? [_BrandPalette.slateRaised, _BrandPalette.slateCard]
                  : [Colors.white, _BrandPalette.warmPaper],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.44),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.05,
                ),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              avatar,
              if (_shellNavExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _setDestination(_ShellDestination.account),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _shellWorkspaceLabel(),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                tooltip: 'Profile menu',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
        );
      },
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

  Widget _buildShellHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final shellEyebrow = _viewerCanManage ? 'TEAM' : 'LEARNING';
    final shellTitle = _viewerCanManage ? _shellTeamName() : 'My learning';
    final shellDescription = _viewerCanManage
        ? 'Learners, sessions, pathways, and profile.'
        : 'Progress and current sessions.';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _shellNavExpanded ? 16 : 10,
        14,
        _shellNavExpanded ? 16 : 10,
        8,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          _shellNavExpanded ? 16 : 8,
          14,
          _shellNavExpanded ? 16 : 8,
          14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [_BrandPalette.slateHigh, _BrandPalette.slateRaised]
                : [Colors.white, _BrandPalette.warmPaper],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.46),
          ),
        ),
        child: _shellNavExpanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shellEyebrow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shellTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildShellRailToggle(theme),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(shellDescription, style: theme.textTheme.bodySmall),
                ],
              )
            : Center(child: _buildShellRailToggle(theme)),
      ),
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context,
    _ShellDestination destination,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _selectedDestination == destination;
    final compactMode = !_shellNavExpanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _setDestination(destination),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compactMode ? 2 : 12,
            vertical: compactMode ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Color.alphaBlend(
                              _BrandPalette.goldBright.withValues(alpha: 0.14),
                              _BrandPalette.slateRaised,
                            ),
                            _BrandPalette.slateCard,
                          ]
                        : [
                            Color.alphaBlend(
                              theme.colorScheme.primary.withValues(alpha: 0.14),
                              Colors.white,
                            ),
                            _BrandPalette.warmPaper,
                          ],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.34)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.46),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.14 : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: compactMode ? 36 : 44,
                height: compactMode ? 36 : 44,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.16 : 0.14,
                        )
                      : theme.colorScheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.24)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.46,
                          ),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  destination.icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              if (_shellNavExpanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopShell(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = Color.alphaBlend(
      isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.72),
      theme.colorScheme.surfaceContainerLow,
    );

    return SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _shellNavExpanded ? 256 : 92,
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? _BrandPalette.slateBorder
                  : theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                _buildShellHeader(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _availableDestinations
                          .map(
                            (destination) =>
                                _buildDesktopNavItem(context, destination),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                  child: _buildProfileMenuAnchor(compact: !_shellNavExpanded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                title: Text(d.label),
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
          onTap: () => _setDestination(_ShellDestination.owner),
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
                child: _buildContentBody(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerView(
    BuildContext context,
    DashboardPayload dashboard,
    LibraryWorkspacePayload libraryWorkspace,
  ) {
    final owners = (_viewerSession?.availableUsers ?? const <ViewerUser>[])
        .where((user) => user.canManageTeam)
        .toList(growable: false);
    return _OwnerWorkspaceView(
      viewer: _currentViewer,
      learners: _visibleLearners,
      owners: owners,
      selectedLearnerId: _selectedLearnerId,
      detail: _learnerDetail,
      libraryWorkspace: libraryWorkspace,
      currentActionSession: _currentActionSession,
      scoreController: _scoreController,
      maxScoreController: _maxScoreController,
      durationController: _durationController,
      notesController: _notesController,
      onSelectLearner: _selectLearner,
      onCreateAssignment: _createAssignment,
      onOpenLibraryRoute: _selectLibraryDocument,
      onOpenLibraryWorkspace: () => _setDestination(_ShellDestination.library),
      onRecordSession: _recordCurrentSession,
      onStartActivity: _startActivityForMaterial,
    );
  }

  Widget _buildLearnerView(BuildContext context) {
    return _LearnerWorkspaceView(
      viewer: _currentViewer,
      workspace: _learnerWorkspace,
      viewerCanReadLibrary: _viewerCanReadLibrary,
      onOpenLibraryRoute: _selectLibraryDocument,
      onStartActivity: _startActivityForMaterial,
    );
  }

  Widget _buildLibraryView(
    BuildContext context,
    LibraryWorkspacePayload libraryWorkspace,
  ) {
    return _LibraryWorkspaceView(
      libraryWorkspace: libraryWorkspace,
      documents: _libraryDocuments,
      activeDocument: _selectedLibraryDocument,
      libraryDocumentBusy: _libraryDocumentBusy,
      viewerCanManage: _viewerCanManage,
      onCreateAssignment: _createAssignment,
      onOpenLibraryRoute: _selectLibraryDocument,
    );
  }
}
