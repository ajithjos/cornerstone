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
                      _googleSigninEnabled && _devUsernameSigninEnabled
                          ? 'Use Google for hosted owner access, or use a bootstrap username in development.'
                          : _googleSigninEnabled
                          ? 'Continue with Google to open the team workspace.'
                          : _devUsernameSigninEnabled
                          ? 'Enter a bootstrap username to continue.'
                          : 'No sign-in methods are configured for this environment yet.',
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
                    if (_googleSigninEnabled && _devUsernameSigninEnabled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or'),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_devUsernameSigninEnabled) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.go,
                        onSubmitted: _authBusy
                            ? null
                            : (_) => _loginWithUsername(),
                        decoration: const InputDecoration(
                          labelText: 'Development username',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _authBusy
                              ? null
                              : () => _loginWithUsername(),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Use bootstrap username'),
                        ),
                      ),
                    ],
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
    final switchableUsers =
        _viewerSession?.availableUsers ?? const <ViewerUser>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _PageHeroCard(
          eyebrow: 'Account',
          title: username,
          description: viewer == null
              ? (dashboard.team?.description ??
                    'Manage your profile and theme in one place.')
              : viewer.canManageTeam
              ? activeViewer != null && activeViewer.userId != viewer.userId
                    ? 'Manage your profile, theme, and team learning space while viewing ${activeViewer.displayName}.'
                    : 'Manage your profile, theme, and team learning space in one place.'
              : 'Keep your profile, theme, and learner space settings in one place.',
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _BrandPalette.goldBright,
                        _BrandPalette.goldDeep,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _identityInitials(username),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _BrandPalette.navy,
                    ),
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
                            ? 'This owner session can manage the team and is currently acting as ${activeViewer.displayName}.'
                            : 'This owner session can manage every learner, assignments, and progress updates.'
                      : 'This account stays focused on the learner view, progress, and pending work.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.14,
                    ),
                    foregroundColor: theme.colorScheme.primary,
                    child: Text(
                      _identityInitials(viewer.displayName),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(viewer.displayName),
                  subtitle: Text(
                    '@${viewer.username}',
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
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      foregroundColor: theme.colorScheme.onTertiaryContainer,
                      child: Text(
                        _identityInitials(activeViewer.displayName),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                                    destination: user.learnerId != null
                                        ? _ShellDestination.learner
                                        : _ShellDestination.account,
                                  ),
                            icon: Icon(
                              user.learnerId != null
                                  ? Icons.school_rounded
                                  : Icons.person_rounded,
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
              Text('Team membership', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Current team and permissions for this account.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (dashboard.team != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.groups_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(dashboard.team!.displayName),
                  subtitle: Text(
                    dashboard.team!.description,
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
                          ? 'Can manage team'
                          : 'Learner view only',
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      textColor: theme.colorScheme.primary,
                    ),
                    _PillBadge(
                      text: viewer.canReadLibrary
                          ? 'Can read library'
                          : 'No library access',
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                    _PillBadge(
                      text: viewer.canViewAllLearners
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
