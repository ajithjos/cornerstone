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
                          ? 'A little learning, every day. Sign in to your learning space.'
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
                      'Parents and teachers sign in first. Choose a learner profile when it is time to practise.',
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
    final viewer = _currentViewer!;
    final active = _activeViewer!;
    final members = _viewerSession?.availableUsers ?? <ViewerUser>[];
    final currentTeam = dashboard.team ?? _viewerSession?.team;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildViewerAvatar(
                    active,
                    size: 56,
                    useGoogleProfile: active.userId == viewer.userId,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_viewerRoleLabel(active)} · ${currentTeam?.displayName ?? 'Learning space'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Signed in with ${viewer.googleEmail ?? viewer.displayName}',
                style: theme.textTheme.bodySmall,
              ),
              if (_hasMeaningfulViewerNotes(active)) ...[
                const SizedBox(height: 8),
                Text(active.notes),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _authBusy ? null : _logoutViewer,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (members.length > 1) ...[
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Switch profile', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                  'Choose a learner when it is time to practise. Choose your owner profile to teach or manage work.',
                ),
                const SizedBox(height: 16),
                for (final member in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _buildViewerAvatar(member, size: 36),
                    title: Text(member.displayName),
                    subtitle: Text(_viewerRoleLabel(member)),
                    trailing: member.userId == active.userId
                        ? const Text('Active')
                        : TextButton(
                            onPressed: _authBusy || _busy
                                ? null
                                : () => _switchActiveUser(
                                    member.userId,
                                    preferredLearnerId: member.learnerId,
                                    destination: member.canManageTeam
                                        ? _ShellDestination.owner
                                        : _ShellDestination.learner,
                                  ),
                            child: const Text('Switch'),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _AppearancePanel(controller: widget.themeController),
        if (_availableTeams.length > 1) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Learning spaces', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final team in _availableTeams)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(team.displayName),
                    trailing: team.teamId == currentTeam?.teamId
                        ? const Text('Current')
                        : TextButton(
                            onPressed: _authBusy || _busy
                                ? null
                                : () => _switchActiveTeam(team.teamId),
                            child: const Text('Open'),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
