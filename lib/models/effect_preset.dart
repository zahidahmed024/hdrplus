import 'dart:convert';

/// Represents a single adjustable effect in the processing pipeline.
class EffectParameter {
  final String name;
  final String label;
  final double min;
  final double max;
  double value;

  EffectParameter({
    required this.name,
    required this.label,
    this.min = -1.0,
    this.max = 1.0,
    this.value = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'min': min,
    'max': max,
    'value': value,
  };

  factory EffectParameter.fromJson(Map<String, dynamic> json) {
    return EffectParameter(
      name: json['name'] as String,
      label: json['label'] as String,
      min: (json['min'] as num?)?.toDouble() ?? -1.0,
      max: (json['max'] as num?)?.toDouble() ?? 1.0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  EffectParameter clone() => EffectParameter(
    name: name,
    label: label,
    min: min,
    max: max,
    value: value,
  );
}

/// A named collection of effect parameters that can be saved/loaded.
class EffectPreset {
  final String id;
  String name;
  final List<EffectParameter> parameters;
  final bool isBuiltIn;
  String? lutPath;

  EffectPreset({
    required this.id,
    required this.name,
    required this.parameters,
    this.isBuiltIn = false,
    this.lutPath,
  });

  /// Returns the value of a parameter by name, or 0 if not found.
  double getValue(String paramName) {
    return parameters
        .firstWhere(
          (p) => p.name == paramName,
          orElse: () => EffectParameter(name: paramName, label: paramName),
        )
        .value;
  }

  /// Sets the value of a parameter by name.
  void setValue(String paramName, double value) {
    final param = parameters.firstWhere(
      (p) => p.name == paramName,
      orElse: () => EffectParameter(name: paramName, label: paramName),
    );
    param.value = value;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parameters': parameters.map((p) => p.toJson()).toList(),
    'isBuiltIn': isBuiltIn,
    'lutPath': lutPath,
  };

  factory EffectPreset.fromJson(Map<String, dynamic> json) {
    return EffectPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      parameters:
          (json['parameters'] as List)
              .map((p) => EffectParameter.fromJson(p as Map<String, dynamic>))
              .toList(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      lutPath: json['lutPath'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory EffectPreset.fromJsonString(String jsonStr) {
    return EffectPreset.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  EffectPreset clone() => EffectPreset(
    id: id,
    name: name,
    parameters: parameters.map((p) => p.clone()).toList(),
    isBuiltIn: isBuiltIn,
    lutPath: lutPath,
  );

  /// Creates the default (neutral) set of effect parameters.
  static List<EffectParameter> defaultParameters() => [
    EffectParameter(
      name: 'contrast',
      label: 'Contrast',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'vibrance',
      label: 'Vibrance',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'clarity',
      label: 'Clarity',
      min: 0.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'shadows',
      label: 'Shadows',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'highlights',
      label: 'Highlights',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'sharpen',
      label: 'Sharpen',
      min: 0.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'denoise',
      label: 'Denoise',
      min: 0.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'saturation',
      label: 'Saturation',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
    EffectParameter(
      name: 'temperature',
      label: 'Temperature',
      min: -1.0,
      max: 1.0,
      value: 0.0,
    ),
  ];

  /// Built-in preset: No Effect (pass-through, no adjustments at all).
  static EffectPreset noEffect() => EffectPreset(
    id: 'no_effect',
    name: 'No Effect',
    parameters: defaultParameters(),
    isBuiltIn: true,
  );

  /// Built-in preset: Natural (neutral, no adjustments).
  static EffectPreset natural() => EffectPreset(
    id: 'natural',
    name: 'Natural',
    parameters: defaultParameters(),
    isBuiltIn: true,
  );

  /// Built-in preset: Vivid (boosted colors and contrast).
  static EffectPreset vivid() {
    final params = defaultParameters();
    _setParam(params, 'contrast', 0.35);
    _setParam(params, 'vibrance', 0.55);
    _setParam(params, 'saturation', 0.35);
    _setParam(params, 'clarity', 0.25);
    return EffectPreset(
      id: 'vivid',
      name: 'Vivid',
      parameters: params,
      isBuiltIn: true,
    );
  }

  /// Built-in preset: Cinematic (warm tones, lifted shadows, slight desat).
  static EffectPreset cinematic() {
    final params = defaultParameters();
    _setParam(params, 'contrast', 0.45);
    _setParam(params, 'shadows', 0.35);
    _setParam(params, 'highlights', -0.25);
    _setParam(params, 'temperature', 0.2);
    _setParam(params, 'saturation', -0.15);
    return EffectPreset(
      id: 'cinematic',
      name: 'Cinematic',
      parameters: params,
      isBuiltIn: true,
    );
  }

  /// Built-in preset: B&W (fully desaturated with strong contrast).
  static EffectPreset blackAndWhite() {
    final params = defaultParameters();
    _setParam(params, 'saturation', -1.0);
    _setParam(params, 'contrast', 0.55);
    _setParam(params, 'clarity', 0.35);
    return EffectPreset(
      id: 'bw',
      name: 'B&W',
      parameters: params,
      isBuiltIn: true,
    );
  }

  /// Built-in preset: HDR Dramatic (strong tone mapping look).
  static EffectPreset hdrDramatic() {
    final params = defaultParameters();
    _setParam(params, 'contrast', 0.25);
    _setParam(params, 'clarity', 0.7);
    _setParam(params, 'shadows', 0.6);
    _setParam(params, 'highlights', -0.5);
    _setParam(params, 'vibrance', 0.35);
    _setParam(params, 'sharpen', 0.35);
    return EffectPreset(
      id: 'hdr_dramatic',
      name: 'HDR Dramatic',
      parameters: params,
      isBuiltIn: true,
    );
  }

  static void _setParam(
    List<EffectParameter> params,
    String name,
    double value,
  ) {
    params.firstWhere((p) => p.name == name).value = value;
  }

  /// Returns all built-in presets.
  static List<EffectPreset> builtInPresets() => [
    noEffect(),
    natural(),
    vivid(),
    cinematic(),
    blackAndWhite(),
    hdrDramatic(),
  ];
}
