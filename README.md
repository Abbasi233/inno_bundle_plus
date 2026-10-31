# Inno Bundle Plus

[![pub package](https://img.shields.io/pub/v/inno_bundle_plus.svg)](https://pub.dev/packages/inno_bundle_plus)
[![inno setup](https://img.shields.io/badge/Inno_Setup-v6.4.0-\-7.1.0-blue)](https://jrsoftware.org/isinfo.php)

CLI tool that simplifies bundling flutter apps into Windows installers using Inno Setup.

> `inno_bundle_plus` is a fork of [`inno_bundle`](https://github.com/hahouari/inno_bundle). It publishes that project together with additional installer features that are not yet available upstream. Report issues and send pull requests for this package to [this repository](https://github.com/Abbasi233/inno_bundle_plus).

# Guide

## 1. Install `inno_bundle_plus` package into your project

```sh
dart pub add dev:inno_bundle_plus
```

## 2. Build the Installer

Run the build command on release mode

```sh
dart run inno_bundle_plus
```

**Note:** This will generate the initial configuration if not present in your `pubspec.yaml`.

# Features

Every key below belongs in the `inno_bundle_plus:` section of `pubspec.yaml`. The first `dart run inno_bundle_plus` writes `id` and `publisher` when they are missing.

## App id (`id`)

GUID that identifies the app to Windows. It must be a UUID. Keep the same value across releases so upgrades replace the existing installation. The first run generates one and saves it.

## Name (`name`)

Name shown in the installer, the Start menu, and the uninstall entry. It must be a valid file name. When omitted, the `name` from `pubspec.yaml` is used.

## Description (`description`)

Text stored as the application description. When omitted, the `description` from `pubspec.yaml` is used.

## Version (`version`)

Version written into the installer file name and the Windows uninstall entry. `inno_bundle_plus.version` overrides the pubspec version. When both are absent, the pubspec `version` is used.

## Publisher (`publisher`)

Publisher name shown in the installer and in Apps & features. `inno_bundle_plus.publisher` overrides the pubspec `maintainer`. The first run writes the Windows user name when neither is set.

## Homepage (`url`)

Publisher link in the installer. When omitted, the pubspec `homepage` is used. An empty value leaves the link blank.

## Support URL (`support_url`)

Support link in the installer. When omitted, `url` is used.

## Updates URL (`updates_url`)

Update link in the installer. When omitted, `url` is used.

## Installer icon (`installer_icon`)

`.ico` file used as the setup icon. A relative path is resolved from the project root. A missing file stops the build. When omitted, the built-in installer icon is used.

## License file (`license_file`)

Text file shown on the license page. A relative path is resolved from the project root. When omitted, a `LICENSE` file at the project root is used if it exists. A missing file skips the license page.

## Languages (`languages`)

List of installer language names, for example `English` and `Turkish`. The names must match the language files of the Inno Setup install used to build. When omitted, every language shipped with that Inno Setup install is included.

## Administrator mode (`admin`)

Controls whether setup asks for administrator rights.

| Value | Behavior |
| --- | --- |
| `true` | Setup requires administrator rights. This is the default. |
| `false` | Setup runs without administrator rights. |
| `auto` | Setup requests administrator rights, and the user can choose otherwise in the wizard or on the command line. |

## CPU architecture (`arch`)

Architecture the installer accepts.

| Value | Behavior |
| --- | --- |
| `x64_compatible` | 64-bit Windows, including ARM64 machines running x64 emulation. This is the default. |
| `x64` | 64-bit x64 Windows only. |

## Visual C++ redistributable (`vc_redist`)

How the installer supplies the Visual C++ runtime Flutter Windows builds need.

| Value | Behavior |
| --- | --- |
| `true` | Copies the runtime DLLs from the build machine's `System32` into the app directory when those files exist. This is the default. |
| `download` | After setup finishes, offers to open the official Visual C++ download. |
| `false` | Does not bundle or download the runtime. |

## Extra files (`files`)

Copies individual files into `{app}`. Each entry is a path string or a map. A plain string is a `path`. A relative path is resolved from the project root.

| Field | Required | Default | Meaning |
| --- | --- | --- | --- |
| `path` | ✅ | | File to copy. |
| `name` | ◼️ | file name of `path` | File name inside the install directory. |
| `destination` | ◼️ | `{app}` | Folder under `{app}`. |
| `source` | ◼️ | `project` | `project` reads the file from the project. `system32` reads it from `System32`. |
| `required` | ◼️ | `true` | A missing required file stops the build. A missing optional file is skipped. |

`dlls` is the old name of this list. Use `files`.

```yaml
inno_bundle_plus:
  files:
    - path: msvcp140.dll
      source: system32
      required: false
```

## Copying folders (`dirs`)

`dirs` copies extra folders into the application directory (`{app}`). Put the list under the `inno_bundle_plus:` section of `pubspec.yaml`. Each entry is a path string or a map.

A relative path is resolved from the project root. An absolute path is read from that location on the machine that builds the installer. The folder's contents, including nested subfolders, are installed under `{app}`. A source folder that is not on disk is skipped.

| Field | Required | Meaning |
| --- | --- | --- |
| `source` | ✅ | Folder to copy. |
| `destination` | ◼️ | Path under `{app}`. When omitted, `source` is used. |

A plain string is a map with only `source`.

When `source` is absolute, set `destination`. An omitted destination keeps the source path, so a drive letter becomes part of the path inside `{app}`.

```yaml
inno_bundle_plus:
  dirs:
    - assets/images
      # OR
    - source: assets/images
      destination: data/images
      # OR
    - source: C:\shared\branding
      destination: branding
```

The first entry installs the contents of `assets/images` at `{app}\assets\images`. The second installs those same contents at `{app}\data\images`. The third reads `C:\shared\branding` and installs it at `{app}\branding`.

## Running programs (`exes`)

`exes` runs programs after the app files have been copied, in list order, on the install page. Setup waits for each program to exit. This happens before the finish page offers to launch the app. Each entry is a path string or a map. A plain string is a `path`.

Set `path` or `source`, and only one of them.

`path` is a file that is already inside `{app}` when that step runs, because the Flutter build or `dirs` placed it there. This entry does not copy the file. `destination` cannot be set together with `path`.

`source` is a file on the build machine. The installer copies it, then runs the copy. A relative `source` is resolved from the project root. An absolute `source` is read from that path. A missing file stops the build. `destination` is the folder under `{app}` that receives the file; the file name stays the same. When `destination` is omitted, a relative `source` keeps its directory (`tools/driver.exe` runs as `{app}\tools\driver.exe`) and an absolute `source` is placed in `{app}`.

A `.msi` file is started with `msiexec /i`. Any other file is started directly. `args` is appended to that command.

| Field | Required | Default | Meaning |
| --- | --- | --- | --- |
| `path` | one of `path` or `source` | | Program already under `{app}`. |
| `source` | one of `path` or `source` | | Program copied into the installer, then run. |
| `destination` | ◼️ | see above | Install folder under `{app}`. Valid only with `source`. |
| `optional` | ◼️ | `false` | When `true`, setup shows a checkbox and runs the program only if the user selects it. |
| `description` | when `optional` is `true` | | Checkbox label. The checkbox is grouped under "Additional programs". |
| `args` | ◼️ | empty | Arguments. For a `.msi`, these follow `msiexec /i`. |
| `status_msg` | ◼️ | `Executing <path>...` | Text on the install page while the program runs. |
| `on_failure` | ◼️ | `continue` | What happens when the program exits with a non-zero code, or cannot be started. |

`on_failure` accepts `continue`, `abort`, and `ask`.

- `continue` leaves the failure behind and moves to the next entry.
- `abort` stops setup and the installation fails.
- `ask` shows Abort, Retry, and Ignore. Abort fails the installation, Retry runs the program again, and Ignore moves on.

```yaml
inno_bundle_plus:
  exes:
    - path: db/scripts/init_schema.exe
      args: /silent
      status_msg: "Initializing database schema..."
      on_failure: abort

    - path: db/scripts/load_sample_data.exe
      optional: true
      description: "Load sample data"
      on_failure: ask

    - source: tools/configure_service.exe
      args: /S
      on_failure: continue
      
    - source: C:\shared\redist\setup.msi
      destination: redist
      optional: true
      description: "Install the database server"
      args: /qn
      status_msg: "Installing the database server..."
      on_failure: ask
```

The first entry runs `{app}\db\scripts\init_schema.exe` and fails the installation if that program fails. The second is a checkbox. The third is copied from the project and run as `{app}\tools\configure_service.exe`. The fourth is copied from an absolute path to `{app}\redist\setup.msi` and installed with `msiexec /i`.

## Code signing (`sign_tool`)

Signs the installer with a tool already installed on the build machine, such as `signtool`. Omit the key to leave the installer unsigned. A string is the command. A map accepts `name`, `command`, `params`, `retry_count`, and `retry_delay`. `command` is the program Inno Setup runs. `$p` in that command is replaced with the file being signed. `params` is appended to the sign command. Retries default to 2 attempts, 500 milliseconds apart.

```yaml
inno_bundle_plus:
  sign_tool:
    command: signtool.exe sign $p
    params: /a /tr http://timestamp.digicert.com
```

## File associations (`file_extensions_associations`)

Registers the app as a handler for the listed extensions and turns on Windows "Open with" for them. Each entry is an extension, and one entry may list several extensions separated by commas. Associations are removed when the app is uninstalled.

```yaml
inno_bundle_plus:
  file_extensions_associations:
    - .pdf
    - .md, .markdown
```

## Removing file associations (`file_extensions_associations_exclude`)

Drops associations that an earlier release registered, without waiting for an uninstall. Use this when an extension leaves `file_extensions_associations`. The entry format is the same.

```yaml
inno_bundle_plus:
  file_extensions_associations_exclude:
    - .md
```

# Reporting Issues

If you encounter any issues <a href="https://github.com/Abbasi233/inno_bundle_plus/issues" target="_blank">please report them here</a>.
