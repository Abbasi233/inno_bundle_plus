import 'dart:io';

import 'package:inno_bundle/models/exe_failure_mode.dart';
import 'package:path/path.dart' as p;

class ExeEntry {
  final String? path;
  final String? source;
  final String? destination;
  final bool optional;
  final String? description;
  final String? args;
  final String? statusMsg;
  final ExeFailureMode onFailure;

  const ExeEntry({
    this.path,
    this.source,
    this.destination,
    this.optional = false,
    this.description,
    this.args,
    this.statusMsg,
    this.onFailure = ExeFailureMode.continue_,
  });

  bool get isAppRelative => path != null;

  bool get isBundled => source != null;

  bool get isMsi => p.extension(installRelativePath).toLowerCase() == '.msi';

  static String? validateConfig(dynamic option, {required String configName}) {
    if (option == null) return null;
    if (option is String) return null;
    if (option is Map<String, dynamic>) {
      final hasPath = option.containsKey('path');
      final hasSource = option.containsKey('source');
      if (hasPath && hasSource) {
        return "inno_bundle.exes entry in $configName must not set both "
            "path and source.";
      }
      if (!hasPath && !hasSource) {
        return "inno_bundle.exes entry in $configName must set path or source.";
      }
      if (hasPath) {
        if (option['path'] is! String) {
          return "path field in inno_bundle.exes entry in $configName "
              "must be a string.";
        }
        if (option['destination'] != null) {
          return "destination field in inno_bundle.exes entry in $configName "
              "is only valid with source, not path.";
        }
      }
      if (hasSource) {
        if (option['source'] is! String) {
          return "source field in inno_bundle.exes entry in $configName "
              "must be a string.";
        }
        if (option['destination'] != null && option['destination'] is! String) {
          return "destination field in inno_bundle.exes entry in $configName "
              "must be a string or null.";
        }
      }
      if (option['optional'] != null && option['optional'] is! bool) {
        return "optional field in inno_bundle.exes entry in $configName "
            "must be a boolean or null.";
      }
      final optional = option['optional'] == true;
      if (optional &&
          (option['description'] == null || option['description'] is! String)) {
        return "description field is required when optional is true in "
            "inno_bundle.exes entry in $configName.";
      }
      if (option['description'] != null && option['description'] is! String) {
        return "description field in inno_bundle.exes entry in $configName "
            "must be a string or null.";
      }
      if (option['args'] != null && option['args'] is! String) {
        return "args field in inno_bundle.exes entry in $configName "
            "must be a string or null.";
      }
      if (option['status_msg'] != null && option['status_msg'] is! String) {
        return "status_msg field in inno_bundle.exes entry in $configName "
            "must be a string or null.";
      }
      if (option['on_failure'] != null &&
          (option['on_failure'] is! String ||
              !ExeFailureMode.literalValues.contains(option['on_failure']))) {
        return "on_failure field in inno_bundle.exes entry in $configName "
            "must be one of ${ExeFailureMode.literalValues.join(', ')} or null.";
      }
      return null;
    }
    return "inno_bundle.exes attribute is invalid in $configName.";
  }

  factory ExeEntry.fromJson(dynamic json) {
    assert(json != null);
    if (json is String) {
      return ExeEntry(path: json);
    }
    final path = json['path'] as String?;
    final source = json['source'] as String?;
    final destination = json['destination'] as String?;
    final optional = json['optional'] as bool? ?? false;
    final description = json['description'] as String?;
    final args = json['args'] as String?;
    final statusMsg = json['status_msg'] as String?;
    final onFailure = ExeFailureMode.fromOption(json['on_failure']);
    return ExeEntry(
      path: path,
      source: source,
      destination: destination,
      optional: optional,
      description: description,
      args: args,
      statusMsg: statusMsg,
      onFailure: onFailure,
    );
  }

  String absoluteSource(Directory baseDir) {
    final src = source;
    if (src == null) {
      throw StateError('absoluteSource is only valid for bundled exes');
    }
    if (p.isAbsolute(src)) return p.normalize(src);
    return p.normalize(p.join(baseDir.path, src));
  }

  String get installRelativePath {
    if (path != null) {
      return _asInnoRelative(path!);
    }
    final src = source!;
    if (destination != null) {
      return _asInnoRelative(p.join(destination!, p.basename(src)));
    }
    if (p.isAbsolute(src)) {
      return p.basename(src);
    }
    return _asInnoRelative(src);
  }

  String get filesDestDirRelative {
    final src = source!;
    if (destination != null) {
      return _asInnoRelative(destination!);
    }
    if (p.isAbsolute(src)) {
      return '';
    }
    final dir = p.dirname(src);
    if (dir == '.' || dir.isEmpty) return '';
    return _asInnoRelative(dir);
  }

  String get filesDestName => p.basename(source!);

  static String _asInnoRelative(String relative) {
    final parts = relative
        .split(RegExp(r'[\\/]+'))
        .where((part) => part.isNotEmpty && part != '.')
        .toList();
    return parts.join('\\');
  }
}
