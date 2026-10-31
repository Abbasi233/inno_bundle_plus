/// This file contains the [ScriptBuilder] class, which is responsible for generating
/// the Inno Setup Script (ISS) file for creating the installer of an application.
///
/// The [ScriptBuilder] class takes a [Config] object and an [appDir] directory as inputs
/// and generates the ISS script based on the provided configuration. This script defines
/// various sections like setup, files, icons, tasks, and languages, among others.
///
/// Key methods:
/// - [_setup]: Generates the `[Setup]` section of the ISS script.
/// - [_installDelete]: Generates the `[InstallDelete]` section.
/// - [_languages]: Generates the `[Languages]` section.
/// - [_tasks]: Generates the `[Tasks]` section.
/// - [_files]: Generates the `[Files]` section.
/// - [_icons]: Generates the `[Icons]` section.
/// - [_run]: Generates the `[Run]` section.
///
/// The [build] method is the main method of this class, which combines all the sections and writes
/// the complete ISS script to a file. It returns the generated script file.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:inno_bundle_plus/models/admin_mode.dart';
import 'package:inno_bundle_plus/models/config.dart';
import 'package:inno_bundle_plus/models/exe_entry.dart';
import 'package:inno_bundle_plus/models/exe_failure_mode.dart';
import 'package:inno_bundle_plus/models/file_entry.dart';
import 'package:inno_bundle_plus/models/vcredist_mode.dart';
import 'package:inno_bundle_plus/utils/cli_logger.dart';
import 'package:inno_bundle_plus/utils/constants.dart';
import 'package:inno_bundle_plus/utils/functions.dart';

/// A class responsible for generating the Inno Setup Script (ISS) file for the installer.
class ScriptBuilder {
  /// The configuration guiding the script generation process.
  final Config config;

  /// The directory containing the application files to be included in the installer.
  final Directory appDir;

  /// Creates a [ScriptBuilder] instance with the given [config] and [appDir].
  ScriptBuilder(this.config, this.appDir);

  String _innoAppDest(String relative) {
    final parts = relative.split(RegExp(r'[\\/]+')).where((part) => part.isNotEmpty && part != '.');
    return '{app}\\${parts.join('\\')}';
  }

  String _escapePascal(String value) => value.replaceAll("'", "''");

  String _escapeIss(String value) => value.replaceAll('"', '""');

  String _exeTaskName(int index) => 'exerun$index';

  /// Generates the `[Setup]` section of the ISS script, containing metadata and
  /// configuration for the installer.
  String _setup() {
    final outputDir = p.joinAll([
      config.baseDir.path,
      ...config.outputDir,
      config.type.dirName,
    ]);

    var installerIcon = config.installerIcon;
    // save default icon into temp directory to use its path.
    if (installerIcon == defaultInstallerIconPlaceholder) {
      final installerIconDirPath = p.joinAll([
        Directory.systemTemp.absolute.path,
        "${camelCase(config.name)}Installer",
      ]);
      installerIcon = persistDefaultInstallerIcon(installerIconDirPath);
    }

    return '''
[Setup]
AppId=${config.id}
AppName=${config.name}
UninstallDisplayName=${config.name}
UninstallDisplayIcon={app}\\${config.pubspecNameDotExe}
AppVersion=${config.version}
AppPublisher=${config.publisher}
AppPublisherURL=${config.url}
AppSupportURL=${config.supportUrl}
AppUpdatesURL=${config.updatesUrl}
LicenseFile=${config.licenseFile}
DefaultDirName={autopf}\\${config.name}
PrivilegesRequired=${config.admin == AdminMode.nonAdmin ? 'lowest' : 'admin'}
PrivilegesRequiredOverridesAllowed=${config.admin == AdminMode.auto ? "dialog commandline" : ""}
OutputDir=$outputDir
OutputBaseFilename=${camelCase(config.name)}-${config.arch.cpu}-${config.version}-Installer
SetupIconFile=$installerIcon
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=${config.arch.innoValue}
ArchitecturesInstallIn64BitMode=${config.arch.innoValue}
DisableDirPage=auto
DisableProgramGroupPage=auto
${config.signTool != null ? config.signTool?.toInnoCode() : ""}
${config.includedFileExts.isNotEmpty || config.excludedFileExts.isNotEmpty ? "ChangesAssociations=yes" : ""}
\n''';
  }

  /// Generates the `[InstallDelete]` section for specifying files to delete during uninstallation.
  String _installDelete() {
    return '''
[InstallDelete]
Type: filesandordirs; Name: "{app}\\*"
\n''';
  }

  /// Generates the `[Languages]` section, defining the languages supported by the installer.
  String _languages() {
    String section = "[Languages]\n";
    for (final language in config.languages) {
      section += '${language.innoEntry}\n';
    }
    return '$section\n';
  }

  /// Generates the `[Tasks]` section, defining additional installation tasks such as creating desktop icons.
  String _tasks() {
    var section = '''
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";
''';
    for (var i = 0; i < config.exes.length; i++) {
      final exe = config.exes[i];
      if (!exe.optional) continue;
      final description = _escapeIss(exe.description!);
      section += 'Name: "${_exeTaskName(i)}"; Description: "$description"; '
          'GroupDescription: "Additional programs";\n';
    }
    return '$section\n';
  }

  /// Generates the `[Files]` section, specifying the files and directories to include in the installer.
  String _files() {
    var section = "[Files]\n";

    // adding app build files
    final appFiles = appDir.listSync();

    for (final appFile in appFiles) {
      final filePath = appFile.absolute.path;
      if (FileSystemEntity.isDirectorySync(filePath)) {
        final fileName = p.basename(filePath);
        section += 'Source: "$filePath\\*"; DestDir: "{app}\\$fileName"; '
            'Flags: ignoreversion recursesubdirs createallsubdirs\n';
      } else {
        section += 'Source: "$filePath"; DestDir: "{app}"; '
            'Flags: ignoreversion\n';
      }
    }

    // additional dirs to copy to the installer build directory
    for (final dir in config.dirs) {
      final sourcePath = dir.absoluteSource(config.baseDir);
      final sourceDir = Directory(sourcePath);
      if (!sourceDir.existsSync()) {
        continue;
      }

      final destDir = _innoAppDest(dir.resolvedDestination);
      section += 'Source: "${sourceDir.absolute.path}\\*"; DestDir: "$destDir"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs\n';
    }

    for (final exe in config.exes) {
      if (!exe.isBundled) continue;
      final sourceFile = File(exe.absoluteSource(config.baseDir));
      if (!sourceFile.existsSync()) {
        CliLogger.exitError("Required exe source ${sourceFile.path} does not exist.");
      }
      final destDirRel = exe.filesDestDirRelative;
      final destDir = destDirRel.isEmpty ? '{app}' : _innoAppDest(destDirRel);
      section += 'Source: "${sourceFile.absolute.path}"; DestDir: "$destDir"; '
          'DestName: "${exe.filesDestName}"; Flags: ignoreversion\n';
    }

    // adding optional files from System32 (if they are available),
    // so that the end user is not required to install
    // MS Visual C++ redistributable to run the app.
    final files = config.files.toList();
    if (config.vcRedist == VcRedistMode.bundle) {
      files.addAll(FileEntry.vcEntries);
    }

    // copy all the files to the installer build directory
    final scriptDirPath = p.joinAll([
      Directory.systemTemp.absolute.path,
      "${camelCase(config.name)}Installer",
      config.type.dirName,
    ]);
    Directory(scriptDirPath).createSync(recursive: true);

    for (final f in files) {
      final file = File(f.absolutePath);
      if (!file.existsSync()) {
        // if the file is not required, skip it, otherwise exit with error.
        if (!f.required) continue;
        CliLogger.exitError("Required file ${file.path} does not exist.");
      }

      final fPath = p.join(scriptDirPath, p.basename(file.path));
      final fName = f.name;
      file.copySync(fPath);
      final destDir = p.join("{app}", f.destination ?? "");
      section += 'Source: "$fPath"; DestDir: "$destDir"; '
          'DestName: "$fName"; Flags: ignoreversion\n';
    }

    return '$section\n';
  }

  /// Generates the `[Icons]` section, defining the shortcuts for the installed application.
  String _icons() {
    return '''
[Icons]
Name: "{autoprograms}\\${config.name}"; Filename: "{app}\\${config.pubspecNameDotExe}"
Name: "{autodesktop}\\${config.name}"; Filename: "{app}\\${config.pubspecNameDotExe}"; Tasks: desktopicon
\n''';
  }

  /// Generates the `[Run]` section, specifying actions to perform after the installation is complete.
  String _run() {
    return '''
[Run]
Filename: "{app}\\${config.pubspecNameDotExe}"; Description: "{cm:LaunchProgram,{#StringChange('${config.name}', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
\n''';
  }

  String _exeExecCall(ExeEntry exe) {
    final rel = exe.installRelativePath;
    final appFile = _escapePascal('{app}\\$rel');
    if (exe.isMsi) {
      final argsSuffix = (exe.args == null || exe.args!.isEmpty) ? '' : ' ${_escapePascal(exe.args!)}';
      final params = "'/i \"' + ExpandConstant('$appFile') + '\"$argsSuffix'";
      return "Exec(ExpandConstant('{sys}\\msiexec.exe'), $params, '', "
          'SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode)';
    }
    final args = _escapePascal(exe.args ?? '');
    return "Exec(ExpandConstant('$appFile'), '$args', '', "
        'SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode)';
  }

  String _exeRunBlock(ExeEntry exe, int index) {
    final rel = exe.installRelativePath;
    final status = _escapePascal(
      exe.statusMsg ?? 'Executing $rel...',
    );
    final taskGuard = exe.optional ? "WizardIsTaskSelected('${_exeTaskName(index)}')" : 'True';
    final failedMsg = _escapePascal('Executable failed: $rel');
    final execCall = _exeExecCall(exe);

    if (exe.onFailure == ExeFailureMode.ask) {
      return '''
  if $taskGuard then
  begin
    WizardForm.StatusLabel.Caption := '$status';
    while True do
    begin
      if not $execCall then
        ResultCode := -1;
      if ResultCode = 0 then Break;
      Response := MsgBox('$failedMsg (exit code ' + IntToStr(ResultCode) + ')' + #13#10 + 'Abort, Retry, or Ignore?', mbError, MB_ABORTRETRYIGNORE);
      if Response = IDABORT then
        RaiseException('$failedMsg');
      if Response = IDIGNORE then Break;
    end;
  end;
''';
    }

    final failureCheck = exe.onFailure == ExeFailureMode.abort
        ? '''
    if ResultCode <> 0 then
      RaiseException('$failedMsg (exit code ' + IntToStr(ResultCode) + ')');
'''
        : '';

    return '''
  if $taskGuard then
  begin
    WizardForm.StatusLabel.Caption := '$status';
    if not $execCall then
      ResultCode := -1;
$failureCheck
  end;
''';
  }

  String _runExesCode() {
    if (config.exes.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('procedure RunConfiguredExes;');
    buf.writeln('var');
    buf.writeln('  ResultCode: Integer;');
    if (config.exes.any((e) => e.onFailure == ExeFailureMode.ask)) {
      buf.writeln('  Response: Integer;');
    }
    buf.writeln('begin');
    for (var i = 0; i < config.exes.length; i++) {
      buf.write(_exeRunBlock(config.exes[i], i));
    }
    buf.writeln('end;');
    buf.writeln();
    return buf.toString();
  }

  String _code() {
    final wantVc = config.vcRedist == VcRedistMode.download;
    final wantExes = config.exes.isNotEmpty;
    if (!wantVc && !wantExes) return '';

    final buf = StringBuffer();
    buf.writeln('[Code]');
    if (wantVc) {
      buf.writeln('var');
      buf.writeln('  RunList: TNewCheckListBox;');
      buf.writeln('  VCCheckBox: TNewCheckBox;');
      buf.writeln();
      buf.writeln('procedure OnWizardFormResize(Sender: TObject);');
      buf.writeln('begin');
      buf.writeln('  if (VCCheckBox <> nil) and (RunList <> nil) and WizardForm.FinishedPage.Visible then');
      buf.writeln('  begin');
      buf.writeln('    VCCheckBox.SetBounds(');
      buf.writeln('      RunList.Left + 4,');
      buf.writeln('      RunList.Top + 25,');
      buf.writeln('      VCCheckBox.Width,');
      buf.writeln('      VCCheckBox.Height');
      buf.writeln('    );');
      buf.writeln('  end;');
      buf.writeln('end;');
      buf.writeln();
      buf.writeln('procedure CurPageChanged(CurPageID: Integer);');
      buf.writeln('begin');
      buf.writeln('  if CurPageID = wpFinished then');
      buf.writeln('  begin');
      buf.writeln('    RunList := WizardForm.RunList;');
      buf.writeln('    if RunList <> nil then');
      buf.writeln('    begin');
      buf.writeln('      VCCheckBox := TNewCheckBox.Create(WizardForm);');
      buf.writeln('      VCCheckBox.Parent := WizardForm.FinishedPage;');
      buf.writeln('      VCCheckBox.SetBounds(');
      buf.writeln('        RunList.Left + 4,');
      buf.writeln('        RunList.Top + 25,');
      buf.writeln('        RunList.Width,');
      buf.writeln('        ScaleY(17)');
      buf.writeln('      );');
      buf.writeln("      VCCheckBox.Caption := 'Download and install required Visual C++ runtime (recommended)';");
      buf.writeln('      VCCheckBox.Checked := True;');
      buf.writeln('      VCCheckBox.Font.Assign(WizardForm.FinishedLabel.Font);');
      buf.writeln('      VCCheckBox.Visible := True;');
      buf.writeln('      WizardForm.OnResize := @OnWizardFormResize;');
      buf.writeln('    end');
      buf.writeln('  end;');
      buf.writeln('end;');
      buf.writeln();
    }

    if (wantExes) {
      buf.write(_runExesCode());
    }

    buf.writeln('procedure CurStepChanged(CurStep: TSetupStep);');
    if (wantVc) {
      buf.writeln('var');
      buf.writeln('  ErrCode: Integer;');
    }
    buf.writeln('begin');
    if (wantExes) {
      buf.writeln('  if CurStep = ssPostInstall then');
      buf.writeln('    RunConfiguredExes;');
    }
    if (wantVc) {
      buf.writeln('  if (CurStep = ssDone) and (VCCheckBox <> nil) and VCCheckBox.Checked then');
      buf.writeln("    ShellExec('', 'https://aka.ms/vs/17/release/vc_redist.x64.exe', '', '', SW_SHOWNORMAL, ewNoWait, ErrCode);");
    }
    buf.writeln('end;');
    buf.writeln();
    return buf.toString();
  }

  (
    String ext,
    String dotExt,
    String regLocationName,
  ) _extCommandParts(String maybeDotExt) {
    final name = config.name;

    String dotExt;
    String ext;
    if (maybeDotExt.startsWith('.')) {
      dotExt = maybeDotExt;
      ext = maybeDotExt.substring(1);
    } else {
      dotExt = '.$maybeDotExt';
      ext = maybeDotExt;
    }
    final regLocationName = '$name$dotExt';
    return (ext, dotExt, regLocationName);
  }

  String _removeOldExtCommand(String fileExt) {
    final regLocationName = _extCommandParts(fileExt).$3;
    return 'Root: HKA; Subkey: "Software\\Classes\\$regLocationName"; Flags: deletekey';
  }

  String _addExtCommand(String fileExt) {
    final name = config.name;
    final (ext, dotExt, regLocationName) = _extCommandParts(fileExt);
    return '''
Root: HKA; Subkey: "Software\\${name}\\Capability\\FileAssociations"; ValueType: string; ValueName: "$dotExt"; ValueData: "$regLocationName"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\\Classes\\$dotExt\\OpenWithProgids"; ValueType: string; ValueName: "$regLocationName"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\\Classes\\$regLocationName"; ValueType: string; ValueName: ""; ValueData: "${ext.toUpperCase()} File"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\\Classes\\$regLocationName\\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\\${config.pubspecNameDotExe},0"
Root: HKA; Subkey: "Software\\Classes\\$regLocationName\\shell\\open\\command"; ValueType: string; ValueName: ""; ValueData: """{app}\\${config.pubspecNameDotExe}"" ""%1"""
Root: HKA; Subkey: "Software\\Classes\\Applications\\${config.pubspecNameDotExe}\\SupportedTypes"; ValueType: string; ValueName: "$dotExt"; ValueData: ""
''';
  }

  String _fileExtsRegistry() {
    if (config.includedFileExts.isEmpty && config.excludedFileExts.isEmpty) {
      return '';
    }
    final name = config.name;
    final createCapabilityKeyCommand = '''
Root: HKA; Subkey: "Software\\${name}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\\${name}\\Capability"; ValueType: string; ValueName: "ApplicationName"; ValueData: "${name}"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\\${name}\\Capability"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "${config.description}"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\\RegisteredApplications"; ValueType: string; ValueName: "${name}"; ValueData: "Software\\${name}\\Capability"; Flags: uninsdeletevalue
''';

    final removedExtsCommands = config.excludedFileExts.map(_removeOldExtCommand).join('\n');
    final addedExtsCommands = config.includedFileExts.map(_addExtCommand).join('\n');

    return '''
[Registry]

$createCapabilityKeyCommand
$removedExtsCommands
$addedExtsCommands
\n''';
  }

  /// Returns the generated ISS script content as a string.
  ///
  /// Does not write to disk — useful for inspection in tests.
  String buildScript() {
    return scriptHeader + _setup() + _installDelete() + _languages() + _tasks() + _files() + _fileExtsRegistry() + _icons() + _run() + _code();
  }

  /// Generates the ISS script file and returns its path.
  Future<File> build() async {
    CliLogger.info("Generating ISS script...");
    final script = buildScript();
    final relScriptPath = p.joinAll([
      ...config.outputDir,
      config.type.dirName,
      "inno-script.iss",
    ]);
    final absScriptPath = p.join(config.baseDir.path, relScriptPath);
    final scriptFile = File(absScriptPath);
    scriptFile.createSync(recursive: true);
    scriptFile.writeAsStringSync(script);
    CliLogger.success("Script generated $relScriptPath");
    return scriptFile;
  }
}
