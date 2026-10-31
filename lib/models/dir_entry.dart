import 'dart:core';
import 'dart:io';

import 'package:path/path.dart' as p;

class DirEntry {
  final String source;
  final String? destination;

  DirEntry({required this.source, this.destination});

  static String? validateConfig(dynamic option) {
    if (option == null) return null;
    if (option is String) return null;
    if (option is Map<String, dynamic>) {
      if (option['source'] == null) {
        return "source field is missing from inno_bundle_plus.dirs entry in pubspec.yaml, "
            "it must be a string.";
      }
      if (option['source'] is! String) {
        return "source field in inno_bundle_plus.dirs entry in pubspec.yaml must be a string.";
      }
      if (option['destination'] != null && option['destination'] is! String) {
        return "destination field in inno_bundle_plus.dirs entry in pubspec.yaml must be a string or null.";
      }
      return null;
    }

    return "inno_bundle_plus.dirs attribute is invalid in pubspec.yaml.";
  }

  factory DirEntry.fromJson(dynamic json) {
    assert(json != null);
    if (json is String) return DirEntry(source: json);

    final source = json['source'] as String;
    final destination = json['destination'] as String?;

    return DirEntry(
      source: source,
      destination: destination,
    );
  }

  String get resolvedDestination => destination ?? source;

  String absoluteSource(Directory baseDir) {
    if (p.isAbsolute(source)) return p.normalize(source);
    return p.normalize(p.join(baseDir.path, source));
  }
}
