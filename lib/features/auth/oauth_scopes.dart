// ── OAuth scope labels ──────────────────────────────────────────────────
// Mirrors funkwhale_api.users.oauth.scopes.BASE_SCOPES for consent UI copy.

/// Human-readable labels for Funkwhale OAuth scopes shown on the authorize
/// consent screen. Unknown scopes fall back to the raw id.
const Map<String, String> kOAuthScopeLabels = {
  'read': 'Read access to your account data',
  'write': 'Write access to your account data',
  'read:profile': 'View profile data (username, e-mail, avatar, …)',
  'write:profile': 'Update profile data',
  'read:libraries': 'View uploads, libraries, and audio metadata',
  'write:libraries': 'Manage uploads, libraries, and audio metadata',
  'read:edits': 'Browse audio metadata edits',
  'write:edits': 'Submit audio metadata edits',
  'read:follows': 'View library follows',
  'write:follows': 'Manage library follows',
  'read:favorites': 'View favorites',
  'write:favorites': 'Manage favorites',
  'read:filters': 'View content filters',
  'write:filters': 'Manage content filters',
  'read:listenings': 'View listening history',
  'write:listenings': 'Record listening history',
  'read:radios': 'View radios',
  'write:radios': 'Manage radios',
  'read:playlists': 'View playlists',
  'write:playlists': 'Manage playlists',
  'read:notifications': 'View personal notifications',
  'write:notifications': 'Manage personal notifications',
  'read:security': 'View security settings',
  'write:security': 'Manage security settings',
  'read:reports': 'View reports',
  'write:reports': 'Submit reports',
  'read:plugins': 'View plugins',
  'write:plugins': 'Manage plugins',
  'read:instance:settings': 'View instance settings',
  'write:instance:settings': 'Manage instance settings',
  'read:instance:users': 'View local user accounts',
  'write:instance:users': 'Manage local user accounts',
  'read:instance:invitations': 'View invitations',
  'write:instance:invitations': 'Manage invitations',
  'read:instance:edits': 'View instance metadata edits',
  'write:instance:edits': 'Manage instance metadata edits',
  'read:instance:libraries': 'View instance libraries and uploads',
  'write:instance:libraries': 'Manage instance libraries and uploads',
  'read:instance:accounts': 'View federated accounts',
  'write:instance:accounts': 'Manage federated accounts',
  'read:instance:domains': 'View instance domains',
  'write:instance:domains': 'Manage instance domains',
  'read:instance:policies': 'View moderation policies',
  'write:instance:policies': 'Manage moderation policies',
  'read:instance:reports': 'View moderation reports',
  'write:instance:reports': 'Manage moderation reports',
  'read:instance:requests': 'View moderation requests',
  'write:instance:requests': 'Manage moderation requests',
  'read:instance:notes': 'View moderation notes',
  'write:instance:notes': 'Manage moderation notes',
};

/// Expand a space-delimited scope string into display entries.
///
/// Broad `read` / `write` tokens are kept as-is (they cover many children).
/// Nested ids get their label when known.
List<({String id, String label})> expandOAuthScopes(String? scope) {
  if (scope == null || scope.trim().isEmpty) {
    return [(id: 'read', label: kOAuthScopeLabels['read']!)];
  }
  final ids = scope
      .split(RegExp(r'\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  // De-dupe while preserving order.
  final seen = <String>{};
  final out = <({String id, String label})>[];
  for (final id in ids) {
    if (!seen.add(id)) continue;
    out.add((id: id, label: kOAuthScopeLabels[id] ?? id));
  }
  return out;
}

/// True for out-of-band OAuth redirect URIs (show code instead of redirect).
bool isOobRedirectUri(String? redirectUri) {
  if (redirectUri == null) return false;
  return redirectUri == 'urn:ietf:wg:oauth:2.0:oob' ||
      redirectUri == 'urn:ietf:wg:oauth:2.0:oob:auto' ||
      redirectUri.startsWith('urn:ietf:wg:oauth:2.0:oob');
}
