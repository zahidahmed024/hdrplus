import '../utils/constants.dart';

/// HDR merge method options.
enum HdrMergeMethod {
  mertens('Exposure Fusion (Mertens)'),
  debevec('Debevec HDR + Tonemap');

  const HdrMergeMethod(this.label);
  final String label;
}

/// Tone mapping algorithm options.
enum ToneMappingCurve {
  none('None'),
  reinhard('Reinhard'),
  drago('Drago'),
  filmic('Filmic');

  const ToneMappingCurve(this.label);
  final String label;
}

/// Configuration for an individual exposure bracket.
class ExposureBracket {
  final double evOffset;
  final String label;

  const ExposureBracket({required this.evOffset, required this.label});
}

/// HDR processing configuration.
class HdrSettings {
  final bool enabled;
  final int bracketCount;
  final double evSpacing;
  final HdrMergeMethod mergeMethod;
  final ToneMappingCurve toneMappingCurve;
  final double toneMappingGamma;
  final bool autoAlign;
  final bool ghostRemoval;

  const HdrSettings({
    this.enabled = false,
    this.bracketCount = HdrDefaults.bracketCount,
    this.evSpacing = HdrDefaults.evSpacing,
    this.mergeMethod = HdrMergeMethod.mertens,
    this.toneMappingCurve = ToneMappingCurve.none,
    this.toneMappingGamma = 1.0,
    this.autoAlign = true,
    this.ghostRemoval = false,
  });

  /// Returns the exposure brackets for this configuration.
  List<ExposureBracket> get brackets {
    final List<ExposureBracket> result = [];
    final halfCount = bracketCount ~/ 2;

    for (int i = -halfCount; i <= halfCount; i++) {
      final ev = i * evSpacing;
      String label;
      if (ev < 0) {
        label = 'Under (${ev.toStringAsFixed(1)} EV)';
      } else if (ev > 0) {
        label = 'Over (+${ev.toStringAsFixed(1)} EV)';
      } else {
        label = 'Normal (0 EV)';
      }
      result.add(ExposureBracket(evOffset: ev, label: label));
    }

    return result;
  }

  HdrSettings copyWith({
    bool? enabled,
    int? bracketCount,
    double? evSpacing,
    HdrMergeMethod? mergeMethod,
    ToneMappingCurve? toneMappingCurve,
    double? toneMappingGamma,
    bool? autoAlign,
    bool? ghostRemoval,
  }) {
    return HdrSettings(
      enabled: enabled ?? this.enabled,
      bracketCount: bracketCount ?? this.bracketCount,
      evSpacing: evSpacing ?? this.evSpacing,
      mergeMethod: mergeMethod ?? this.mergeMethod,
      toneMappingCurve: toneMappingCurve ?? this.toneMappingCurve,
      toneMappingGamma: toneMappingGamma ?? this.toneMappingGamma,
      autoAlign: autoAlign ?? this.autoAlign,
      ghostRemoval: ghostRemoval ?? this.ghostRemoval,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'bracketCount': bracketCount,
    'evSpacing': evSpacing,
    'mergeMethod': mergeMethod.name,
    'toneMappingCurve': toneMappingCurve.name,
    'toneMappingGamma': toneMappingGamma,
    'autoAlign': autoAlign,
    'ghostRemoval': ghostRemoval,
  };

  factory HdrSettings.fromJson(Map<String, dynamic> json) {
    return HdrSettings(
      enabled: json['enabled'] as bool? ?? false,
      bracketCount: json['bracketCount'] as int? ?? HdrDefaults.bracketCount,
      evSpacing:
          (json['evSpacing'] as num?)?.toDouble() ?? HdrDefaults.evSpacing,
      mergeMethod: HdrMergeMethod.values.firstWhere(
        (e) => e.name == json['mergeMethod'],
        orElse: () => HdrMergeMethod.mertens,
      ),
      toneMappingCurve: ToneMappingCurve.values.firstWhere(
        (e) => e.name == json['toneMappingCurve'],
        orElse: () => ToneMappingCurve.none,
      ),
      toneMappingGamma: (json['toneMappingGamma'] as num?)?.toDouble() ?? 1.0,
      autoAlign: json['autoAlign'] as bool? ?? true,
      ghostRemoval: json['ghostRemoval'] as bool? ?? false,
    );
  }
}
