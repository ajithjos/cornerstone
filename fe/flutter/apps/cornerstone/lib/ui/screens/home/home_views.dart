part of '../../../main.dart';

extension _CornerstoneHomePageViews on _CornerstoneHomePageState {
  Widget _buildSignedOutScaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: _SurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandLockup(),
                    const SizedBox(height: 18),
                    Text(
                      'Sign in',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _googleSigninEnabled
                          ? 'Continue with Google to open the team workspace.'
                          : 'Google sign-in is not configured for this environment yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_sessionErrorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _sessionErrorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_googleSigninEnabled) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _authBusy ? null : _loginWithGoogle,
                          icon: _authBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Only owners already provisioned in the identity bootstrap can sign in. Learners switch profiles after an owner signs in.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentBody(BuildContext context) {
    final dashboard = _dashboard;
    final libraryWorkspace = _libraryWorkspace;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: () => _loadAll());
    }
    if (dashboard == null) {
      return const Center(child: Text('No data loaded'));
    }
    final activeDestination =
        _availableDestinations.contains(_selectedDestination)
        ? _selectedDestination
        : (_availableDestinations.isNotEmpty
              ? _availableDestinations.first
              : _ShellDestination.account);
    final content = switch (activeDestination) {
      _ShellDestination.owner =>
        libraryWorkspace == null
            ? const Center(child: Text('Team planning data is unavailable.'))
            : _buildOwnerView(context, dashboard, libraryWorkspace),
      _ShellDestination.learner => _buildLearnerView(context),
      _ShellDestination.library =>
        libraryWorkspace == null
            ? const Center(
                child: Text('Library access is unavailable for this viewer.'),
              )
            : _buildLibraryView(context, libraryWorkspace),
      _ShellDestination.account => _buildAccountView(context, dashboard),
    };
    return _wrapMainContent(
      content,
      maxWidth: _contentMaxWidthFor(activeDestination),
    );
  }

  Widget _buildAccountView(BuildContext context, DashboardPayload dashboard) {
    final theme = Theme.of(context);
    final username = _shellUsername();
    final viewer = _currentViewer;
    final activeViewer = _activeViewer;
    final availableTeams = _availableTeams;
    final switchableUsers =
        _viewerSession?.availableUsers ?? const <ViewerUser>[];
    final currentTeam = dashboard.team ?? _viewerSession?.team;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _PageHeroCard(
          eyebrow: 'Account',
          title: username,
          description: viewer == null
              ? (dashboard.team?.description ??
                    'Manage your profile and theme in one place.')
              : activeViewer != null && activeViewer.userId != viewer.userId
              ? 'Signed in as ${viewer.displayName} and currently viewing ${activeViewer.displayName} in this team space.'
              : 'Signed in as ${viewer.displayName}. Manage your team space, theme, and profile in one place.',
          trailing: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildViewerAvatar(
                  viewer,
                  size: 60,
                  brandedInitials: viewer?.profilePictureUrl == null,
                  initialsStyle: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _BrandPalette.navy,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _viewerRoleLabel(viewer),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  viewer == null ? 'Signed out' : '@${viewer.username}',
                  style: theme.textTheme.bodySmall,
                ),
                if (viewer?.googleSignedIn ?? false) ...[
                  const SizedBox(height: 8),
                  _PillBadge(
                    text: 'Google sign-in',
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    textColor: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (viewer != null) ...[
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  viewer.canManageTeam
                      ? activeViewer != null &&
                                activeViewer.userId != viewer.userId
                            ? 'Signed in owner stays ${viewer.displayName}. The on-screen learner profile is ${activeViewer.displayName}.'
                            : 'This owner session can switch teams, learners, assignments, and progress views.'
                      : 'This account stays focused on the learner view, progress, and pending work.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _buildViewerAvatar(
                    viewer,
                    size: 40,
                    useGoogleProfile: true,
                  ),
                  title: Text(
                    viewer.googleSignedIn
                        ? 'Signed in owner: ${viewer.profileLabel}'
                        : 'Signed in owner: ${viewer.displayName}',
                  ),
                  subtitle: Text(
                    viewer.googleSignedIn &&
                            (viewer.googleEmail?.trim().isNotEmpty ?? false)
                        ? viewer.googleEmail!.trim()
                        : '@${viewer.username}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: _PillBadge(
                    text: _viewerRoleLabel(viewer),
                    color: viewer.canManageTeam
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    textColor: viewer.canManageTeam
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.primary,
                  ),
                ),
                if (activeViewer != null &&
                    activeViewer.userId != viewer.userId) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _buildViewerAvatar(
                      activeViewer,
                      size: 40,
                      useGoogleProfile: false,
                    ),
                    title: Text('Active profile: ${activeViewer.displayName}'),
                    subtitle: Text(
                      '@${activeViewer.username}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: _PillBadge(
                      text: activeViewer.role,
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
                if (viewer.currentLevel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Current level: ${viewer.currentLevel}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (_hasMeaningfulViewerNotes(viewer)) ...[
                  const SizedBox(height: 8),
                  Text(
                    viewer.notes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (availableTeams.length > 1) ...[
                  const SizedBox(height: 18),
                  Text('Switch team space', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Move this owner session into another bootstrap team where the signed-in owner is allowed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableTeams
                        .map(
                          (team) => OutlinedButton.icon(
                            onPressed:
                                _authBusy ||
                                    _busy ||
                                    team.teamId == currentTeam?.teamId
                                ? null
                                : () => _switchActiveTeam(team.teamId),
                            icon: const Icon(Icons.groups_rounded, size: 18),
                            label: Text(team.displayName),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (switchableUsers.length > 1) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Switch active profile',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep one owner sign-in, then switch the active team member for this browser session.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: switchableUsers
                        .map(
                          (user) => OutlinedButton.icon(
                            onPressed:
                                _authBusy || user.userId == activeViewer?.userId
                                ? null
                                : () => _switchActiveUser(
                                    user.userId,
                                    preferredLearnerId: user.learnerId,
                                    destination: user.canManageTeam
                                        ? _ShellDestination.owner
                                        : _ShellDestination.learner,
                                  ),
                            icon: Icon(
                              user.learnerId != null
                                  ? CornerstoneIcons.learning
                                  : CornerstoneIcons.profile,
                              size: 18,
                            ),
                            label: Text(user.displayName),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _authBusy ? null : _logoutViewer,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Team space', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Current team and on-screen profile for this signed-in owner session.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (currentTeam != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.groups_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(currentTeam.displayName),
                  subtitle: Text(
                    currentTeam.description,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                Text(
                  'No team information available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (viewer != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillBadge(
                      text: 'Role: ${viewer.role}',
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                    _PillBadge(
                      text: viewer.canManageTeam
                          ? 'Owner session'
                          : 'Learner view only',
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      textColor: theme.colorScheme.primary,
                    ),
                    _PillBadge(
                      text:
                          (activeViewer?.canReadLibrary ??
                              viewer.canReadLibrary)
                          ? 'Can read library'
                          : 'No library access',
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                    _PillBadge(
                      text:
                          (activeViewer?.canViewAllLearners ??
                              viewer.canViewAllLearners)
                          ? 'Can view all learners'
                          : 'Can view assigned learner only',
                      color: theme.colorScheme.surfaceContainerHighest,
                      textColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    if (activeViewer != null)
                      _PillBadge(
                        text: 'Active: ${activeViewer.displayName}',
                        color: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
