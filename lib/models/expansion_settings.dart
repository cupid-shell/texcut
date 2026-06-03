/// How an expansion is triggered as the user types.
enum TriggerMode {
  /// Replace as soon as the exact shortcut has been typed.
  instant,

  /// Replace only once the shortcut is followed by a delimiter
  /// (space, newline or punctuation). Avoids expanding prefixes of words.
  onDelimiter,
}

extension TriggerModeX on TriggerMode {
  String get id => name;
  String get label => switch (this) {
        TriggerMode.instant => 'Instant',
        TriggerMode.onDelimiter => 'After a space / punctuation',
      };

  static TriggerMode fromId(String? id) =>
      TriggerMode.values.firstWhere((m) => m.id == id,
          orElse: () => TriggerMode.onDelimiter);
}

/// User-tunable behaviour for the expander, shared between the in-app
/// text fields and the system-wide accessibility service.
class ExpansionSettings {
  const ExpansionSettings({
    this.serviceEnabled = true,
    this.triggerMode = TriggerMode.onDelimiter,
    this.requireWordBoundary = true,
    this.caseSensitive = true,
    this.hapticFeedback = true,
    this.dateFormat = 'yyyy-MM-dd',
    this.timeFormat = 'HH:mm',
  });

  /// Master switch for system-wide expansion (independent of the OS toggle).
  final bool serviceEnabled;
  final TriggerMode triggerMode;
  final bool requireWordBoundary;
  final bool caseSensitive;
  final bool hapticFeedback;
  final String dateFormat;
  final String timeFormat;

  ExpansionSettings copyWith({
    bool? serviceEnabled,
    TriggerMode? triggerMode,
    bool? requireWordBoundary,
    bool? caseSensitive,
    bool? hapticFeedback,
    String? dateFormat,
    String? timeFormat,
  }) {
    return ExpansionSettings(
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      triggerMode: triggerMode ?? this.triggerMode,
      requireWordBoundary: requireWordBoundary ?? this.requireWordBoundary,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }

  Map<String, dynamic> toJson() => {
        'serviceEnabled': serviceEnabled,
        'triggerMode': triggerMode.id,
        'requireWordBoundary': requireWordBoundary,
        'caseSensitive': caseSensitive,
        'hapticFeedback': hapticFeedback,
        'dateFormat': dateFormat,
        'timeFormat': timeFormat,
      };

  factory ExpansionSettings.fromJson(Map<String, dynamic> json) =>
      ExpansionSettings(
        serviceEnabled: json['serviceEnabled'] as bool? ?? true,
        triggerMode: TriggerModeX.fromId(json['triggerMode'] as String?),
        requireWordBoundary: json['requireWordBoundary'] as bool? ?? true,
        caseSensitive: json['caseSensitive'] as bool? ?? true,
        hapticFeedback: json['hapticFeedback'] as bool? ?? true,
        dateFormat: json['dateFormat'] as String? ?? 'yyyy-MM-dd',
        timeFormat: json['timeFormat'] as String? ?? 'HH:mm',
      );
}
