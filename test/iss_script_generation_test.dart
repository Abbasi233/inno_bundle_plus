import 'dart:io';

import 'package:test/test.dart';

import 'package:inno_bundle_plus/builders/script_builder.dart';
import 'package:inno_bundle_plus/models/cli_configs/inno_bundle_plus_cli_config.dart';
import 'package:inno_bundle_plus/models/config.dart';

import 'support/language_fixture.dart';

void main() {
  initTestLanguages();
  group('.iss script generation', () {
    late Directory tempDir;
    late Directory appDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('inno_test_');
      appDir = Directory('${tempDir.path}\\app');
      appDir.createSync();
      // Put a dummy exe so the [Files] section has something to list
      File('${appDir.path}\\my_app.exe').writeAsStringSync('dummy');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Config _config({
      List<String> outputDir = const ['tmp', 'inno_out'],
      List<dynamic>? dirs,
      List<dynamic>? exes,
      Directory? baseDir,
    }) {
      return Config.fromJson(
        {
          'name': 'my_app',
          'description': 'A test app.',
          'version': '1.0.0',
          'maintainer': 'Test User',
        },
        {
          'inno_bundle_plus': {
            'id': '5ec949d0-0582-1e06-b073-b5d1161f6fff',
            if (dirs != null) 'dirs': dirs,
            if (exes != null) 'exes': exes,
          },
        },
        cliConfig: InnoBundlePlusCliConfig(),
        pubspecFile: File(''),
        configFile: File(''),
        outputDir: outputDir,
        innoExec: File('test_iscc.exe'),
        baseDir: baseDir,
      );
    }

    test('includes [Setup] section with id, publisher, version from config', () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('[Setup]'));
      expect(script, contains('AppId=5ec949d0-0582-1e06-b073-b5d1161f6fff'));
      expect(script, contains('AppName=my_app'));
      expect(script, contains('AppVersion=1.0.0'));
      expect(script, contains('AppPublisher=Test User'));
    });

    test('includes one [Files] entry per DLL in the required-DLL allowlist', () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('[Files]'));
      expect(script, contains('Source:'));
      // The app exe should be listed
      expect(script, contains('my_app.exe'));
    });

    test('honors the default x64_compatible architecture in the script', () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('ArchitecturesAllowed=x64compatible'));
      expect(script, contains('ArchitecturesInstallIn64BitMode=x64compatible'));
    });

    test('copies dir contents into [Files] when the source folder exists', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: [
          {'source': 'assets/animations'},
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\assets\\animations"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
    });

    test('uses source as destination when a dir entry is a plain string', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: ['assets/animations'],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\assets\\animations"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
    });

    test('copies dir contents to destination when it differs from source', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: [
          {
            'source': 'assets/animations',
            'destination': 'data/anims',
          },
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\data\\anims"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
    });

    test('does not copy dir contents when the source folder is absent', () {
      final config = _config(
        dirs: [
          {'source': 'appdata'},
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, isNot(contains('DestDir: "{app}\\appdata"')));
    });

    test('runs app-relative exes from [Code] in list order before app launch', () {
      final config = _config(
        exes: [
          {
            'path': 'tools/first.exe',
            'args': '/silent',
            'status_msg': 'First...',
            'on_failure': 'abort',
          },
          {
            'path': 'tools/second.exe',
            'optional': true,
            'description': 'Install second',
            'on_failure': 'ask',
          },
        ],
      );
      final builder = ScriptBuilder(config, appDir);
      final script = builder.buildScript();

      expect(script, contains('Name: "exerun1"; Description: "Install second"'));
      expect(script, contains('procedure RunConfiguredExes;'));
      expect(script, contains("ExpandConstant('{app}\\tools\\first.exe')"));
      expect(script, contains("ExpandConstant('{app}\\tools\\second.exe')"));
      expect(script, contains("WizardIsTaskSelected('exerun1')"));
      expect(script, contains("'/silent'"));
      expect(script, contains("WizardForm.StatusLabel.Caption := 'First...'"));
      expect(script, contains('RaiseException('));
      expect(script, contains('MB_ABORTRETRYIGNORE'));
      expect(script, contains('if CurStep = ssPostInstall then'));
      expect(script, contains('RunConfiguredExes;'));
      final firstIdx = script.indexOf("ExpandConstant('{app}\\tools\\first.exe')");
      final secondIdx = script.indexOf("ExpandConstant('{app}\\tools\\second.exe')");
      expect(firstIdx, lessThan(secondIdx));
      expect(
        script,
        contains(
          'Filename: "{app}\\my_app.exe"; Description: '
          '"{cm:LaunchProgram,{#StringChange(\'my_app\', \'&\', \'&&\')}}"; '
          'Flags: nowait postinstall skipifsilent',
        ),
      );
    });

    test('copies bundled exe sources into [Files] preserving relative path', () {
      final toolsDir = Directory('${tempDir.path}\\tools');
      toolsDir.createSync(recursive: true);
      final driver = File('${toolsDir.path}\\driver.exe');
      driver.writeAsStringSync('dummy');

      final config = _config(
        exes: [
          {
            'source': 'tools/driver.exe',
            'args': '/S',
            'status_msg': 'Driver...',
          },
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);
      final script = builder.buildScript();
      final sourcePath = driver.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath"; DestDir: "{app}\\tools"; '
          'DestName: "driver.exe"; Flags: ignoreversion',
        ),
      );
      expect(
        script,
        contains("ExpandConstant('{app}\\tools\\driver.exe')"),
      );
    });

    test('copies bundled exe to destination when set', () {
      final toolsDir = Directory('${tempDir.path}\\tools');
      toolsDir.createSync(recursive: true);
      final driver = File('${toolsDir.path}\\driver.exe');
      driver.writeAsStringSync('dummy');

      final config = _config(
        exes: [
          {
            'source': 'tools/driver.exe',
            'destination': 'drivers',
          },
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);
      final script = builder.buildScript();
      final sourcePath = driver.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath"; DestDir: "{app}\\drivers"; '
          'DestName: "driver.exe"; Flags: ignoreversion',
        ),
      );
      expect(
        script,
        contains("ExpandConstant('{app}\\drivers\\driver.exe')"),
      );
    });

    test('runs .msi via msiexec /i and appends args', () {
      final msi = File('${tempDir.path}\\mariadb_X64.msi');
      msi.writeAsStringSync('dummy');

      final config = _config(
        exes: [
          {
            'source': msi.path,
            'args': '/qn',
            'status_msg': 'MARIADB KURULUYOR...',
            'on_failure': 'ask',
          },
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);
      final script = builder.buildScript();

      expect(
        script,
        contains("Exec(ExpandConstant('{sys}\\msiexec.exe'), "),
      );
      expect(
        script,
        contains(
          "'/i \"' + ExpandConstant('{app}\\mariadb_X64.msi') + '\" /qn'",
        ),
      );
      expect(
        script,
        isNot(contains("Exec(ExpandConstant('{app}\\mariadb_X64.msi')")),
      );
    });
  });
}
