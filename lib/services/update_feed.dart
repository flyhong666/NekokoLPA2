/// Selects updates without crossing between public and vendor distributions.
class UpdateFeed {
  UpdateFeed._();

  static final _signature = RegExp(r'^[a-fA-F0-9]{40}$');

  static Map<String, dynamic>? selectAndroid(
    Map config, {
    required String variant,
    required Iterable<String> signatures,
    required int currentBuild,
  }) {
    final installed = signatures.map((s) => s.toLowerCase()).toSet();
    Map<String, dynamic>? best;
    var highest = currentBuild;
    for (final entry in config.entries) {
      final key = entry.key.toString();
      // `open-rooted-<cert>` must never match the `open` channel.
      final suffix = key.startsWith('$variant-')
          ? key.substring(variant.length + 1)
          : '';
      if (key != variant &&
          (suffix.isEmpty || !suffix.split('-').every(_signature.hasMatch))) {
        continue;
      }
      final releases = entry.value is List
          ? entry.value as List
          : [entry.value];
      for (final value in releases) {
        if (value is! Map) continue;
        final build = value['build'];
        if (build is! int || build <= highest) continue;
        final allowed = value['signatures'];
        final unrestricted =
            allowed == null || (allowed is List && allowed.isEmpty);
        final publicBuild = variant == 'open' || variant == 'open-rooted';
        if (unrestricted && publicBuild) continue;
        final matches =
            unrestricted ||
            (allowed is List &&
                allowed.any(
                  (s) => installed.contains(s.toString().toLowerCase()),
                ));
        if (!matches) continue;
        highest = build;
        best = Map<String, dynamic>.from(value);
      }
    }
    return best;
  }

  static Map<String, dynamic>? selectDesktop(
    Map config, {
    required String variant,
    required int currentBuild,
  }) {
    // Old public builds embedded `store`; keep them on the public channel.
    final channel = variant == 'store' ? 'open' : variant;
    final publicBuild = channel == 'open' || channel == 'open-rooted';
    final value =
        config[channel] ?? (publicBuild ? null : config['std'] ?? config);
    if (value is! Map || value['build'] is! int) return null;
    if ((value['build'] as int) <= currentBuild) return null;
    return Map<String, dynamic>.from(value);
  }
}
