# BSADellDriverPack

![Static Badge](https://img.shields.io/badge/made%20with-PowerShell-blue) [![PowerShell Gallery](https://img.shields.io/powershellgallery/v/BSADellDriverPack.svg)](https://www.powershellgallery.com/packages/BSADellDriverPack) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

BSADellDriverPack is a PowerShell module to download Dell driver packs (CAB files).

## Description

This module downloads the Dell Driver Pack Catalog, then downloads every driver pack CAB file matching the requested models, operating systems and architectures.

It is possible to filter according to:
* computer models
* operating systems
* processor architecture
* age of CAB files

Packages already downloaded (and valid) are skipped, duplicate copies are created as hard links by default (no admin rights needed), and older versions of a package are removed once a newer one has been downloaded.

## Getting started

### Prerequisites

* Windows 7+ / Windows Server 2008+
* PowerShell v5.1+
* Administrator privileges (only required when using `-DuplicateHandling SymbolicLink`; the default `HardLink` mode does not need elevation)

### Installation

You can install this module from the PowerShell Gallery.

```powershell
Install-Module -Name BSADellDriverPack
```

### Usage

Download CAB files less than 12 months old

```powershell
Get-DriversPackFromDell -MonthsBack 12
```

Download CAB files less than 6 months old corresponding to x86 or x64 architectures and Windows 7 or 10 operating systems :

```powershell
Get-DriversPackFromDell -Architectures x86, x64 -OperatingSystems Windows10, Windows7 -MonthsBack 6
```

Download CAB files corresponding to models Latitude 7370 or Latitude 7490

```powershell
Get-DriversPackFromDell -Models 'Latitude 7370', 'Latitude 7490'
```

*Remember to take advantage of auto-completion, especially for computer models. Tab-completion values are cached under `$env:LOCALAPPDATA\BSADellDriverPack` after the first run.*

By default, CAB files are downloaded to `$env:LOCALAPPDATA\BSADellDriverPack\Drivers`. Use `-DownloadFolder` to change the destination, and `-DriversStructure` to change how packages are sorted into subfolders.

When the same package is needed in several places in that structure, duplicates are reconciled with `-DuplicateHandling` :
* `HardLink` (default) : no admin rights required, but source and destination must be on the same volume.
* `SymbolicLink` : requires admin rights.
* `Copy` : uses more disk space, but works across volumes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Authors

* **Brice Sarrazin** - *Initial work*
