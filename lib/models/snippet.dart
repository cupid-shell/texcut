import 'dart:math';

import 'expansion_settings.dart';

/// A single text-expansion rule: when the user types [shortcut], it is
/// replaced with [expansion].
class Snippet {
  Snippet({
    required this.id,
    required this.shortcut,
    required this.expansion,
    this.label = '',
    this.group = 'General',
    this.enabled = true,
    this.pinned = false,
    this.usageCount = 0,
    this.triggerMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastUsedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Sentinel so [copyWith] can tell "leave unchanged" from "set to null".
  static const Object _unset = Object();

  final String id;
  final String shortcut;
  final String expansion;
  final String label;
  final String group;
  final bool enabled;
  final bool pinned;
  final int usageCount;

  /// Per-snippet trigger override. `null` means "follow the global setting".
  final TriggerMode? triggerMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  /// A human friendly title for lists: the label if present, else the shortcut.
  String get displayTitle => label.trim().isNotEmpty ? label.trim() : shortcut;

  Snippet copyWith({
    String? shortcut,
    String? expansion,
    String? label,
    String? group,
    bool? enabled,
    bool? pinned,
    int? usageCount,
    Object? triggerMode = _unset,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return Snippet(
      id: id,
      shortcut: shortcut ?? this.shortcut,
      expansion: expansion ?? this.expansion,
      label: label ?? this.label,
      group: group ?? this.group,
      enabled: enabled ?? this.enabled,
      pinned: pinned ?? this.pinned,
      usageCount: usageCount ?? this.usageCount,
      triggerMode: identical(triggerMode, _unset)
          ? this.triggerMode
          : triggerMode as TriggerMode?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shortcut': shortcut,
        'expansion': expansion,
        'label': label,
        'group': group,
        'enabled': enabled,
        'pinned': pinned,
        'usageCount': usageCount,
        if (triggerMode != null) 'triggerMode': triggerMode!.id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as String,
        shortcut: json['shortcut'] as String? ?? '',
        expansion: json['expansion'] as String? ?? '',
        label: json['label'] as String? ?? '',
        group: json['group'] as String? ?? 'General',
        enabled: json['enabled'] as bool? ?? true,
        pinned: json['pinned'] as bool? ?? false,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
        triggerMode: json['triggerMode'] == null
            ? null
            : TriggerModeX.fromId(json['triggerMode'] as String?),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      );

  /// Generates a reasonably unique id without pulling in an extra dependency.
  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = Random().nextInt(1 << 32);
    return '${now.toRadixString(36)}-${salt.toRadixString(36)}';
  }
}
