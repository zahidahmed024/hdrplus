/// Export format and quality configuration.
library;

enum ExportFormat {
  jpeg('JPEG', 'jpg'),
  png16bit('PNG 16-bit', 'png');

  const ExportFormat(this.label, this.extension);
  final String label;
  final String extension;
}

class ExportSettings {
  final ExportFormat format;
  final int jpegQuality;
  final bool preserveMetadata;

  const ExportSettings({
    this.format = ExportFormat.jpeg,
    this.jpegQuality = 95,
    this.preserveMetadata = true,
  });

  ExportSettings copyWith({
    ExportFormat? format,
    int? jpegQuality,
    bool? preserveMetadata,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'jpegQuality': jpegQuality,
    'preserveMetadata': preserveMetadata,
  };

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    return ExportSettings(
      format: ExportFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => ExportFormat.jpeg,
      ),
      jpegQuality: json['jpegQuality'] as int? ?? 95,
      preserveMetadata: json['preserveMetadata'] as bool? ?? true,
    );
  }
}
