class ActivityPresentation {
  const ActivityPresentation({
    required this.packageId,
    required this.version,
    required this.entryUrl,
    required this.protocolVersion,
    required this.payload,
  });
  final String packageId;
  final String version;
  final String entryUrl;
  final int protocolVersion;
  final Map<String, dynamic> payload;

  factory ActivityPresentation.fromJson(Map<String, dynamic> json) =>
      ActivityPresentation(
        packageId: json['package_id'] as String,
        version: json['version'] as String,
        entryUrl: json['entry_url'] as String,
        protocolVersion: json['protocol_version'] as int,
        payload: json['payload'] as Map<String, dynamic>,
      );

  Uri validatedEntryUri(String apiBaseUrl) {
    final base = Uri.parse(apiBaseUrl);
    final supplied = Uri.parse(entryUrl);
    // Uri normalizes dot segments, so reject traversal before resolving it.
    final rawPath = Uri.decodeComponent(
      entryUrl.split('?').first,
    ).replaceAll(r'\', '/');
    final entry = base.resolve(entryUrl);
    final safeSegment = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$');
    final packagePath = '/api/v1/activity-packages/$packageId/$version/';
    final integrity = entry.queryParametersAll['integrity'];
    if (protocolVersion != 1 ||
        RegExp(r'(^|/)\.{1,2}(/|$)').hasMatch(rawPath) ||
        !safeSegment.hasMatch(packageId) ||
        !safeSegment.hasMatch(version) ||
        !['http', 'https'].contains(base.scheme) ||
        entry.origin != base.origin ||
        !entry.path.startsWith(packagePath) ||
        !entry.path.endsWith('.html') ||
        supplied.pathSegments.any(
          (segment) =>
              segment == '.' ||
              segment == '..' ||
              !safeSegment.hasMatch(segment),
        ) ||
        entry.queryParametersAll.length != 1 ||
        integrity == null ||
        integrity.length != 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(integrity.single) ||
        entry.hasFragment ||
        entry.userInfo.isNotEmpty) {
      throw const FormatException(
        'This activity cannot be opened from the supplied address.',
      );
    }
    return entry;
  }
}
