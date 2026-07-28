---
title: Language Starters
sidebar_position: 1
description: Patterns for extending project generation to additional languages.
---

# Language Starter Scripts

**Documentation for extending setup-project.ps1 with language-specific setup**

This directory contains modular PowerShell scripts for generating language-specific starter files when creating a new project.

## Overview

The `setup-project.ps1` script automatically calls language starter scripts if they exist:

```powershell
setup-starter-<language>.ps1
```

This allows projects to have:
- Language-specific configuration files (package.json, Cargo.toml, etc.)
- Starter source code and test stubs
- Build/development tool configurations
- Dependency specifications

## Existing Starters

### Node.js — `setup-starter-node.ps1`

**Generates:**
- `package.json` — Dependencies and scripts
- `tsconfig.json` — TypeScript configuration
- `.eslintrc.json` — Code linting rules
- `jest.config.js` — Test runner configuration
- `.prettierrc.json` — Code formatter settings
- `src/index.js` — Starter entry point
- `tests/index.test.js` — Starter test file

**Usage:**
```powershell
.\scripts\setup-project.ps1 -ProjectPath 'D:\Projects\MyApp' -ProjectName 'MyApp' -Language 'node'
```

### Python — `setup-starter-python.ps1`

**Generates:**
- `requirements.txt` — Production dependencies
- `requirements-dev.txt` — Development dependencies
- `setup.py` — Package installation script
- `pyproject.toml` — Modern Python project config
- `pytest.ini` — Test runner configuration
- `.flake8` — Code style checker
- `src/__init__.py` — Package initialization
- `src/main.py` — Starter entry point
- `tests/test_main.py` — Starter test file

**Usage:**
```powershell
.\scripts\setup-project.ps1 -ProjectPath 'D:\Projects\MyApp' -ProjectName 'MyApp' -Language 'python'
```

## Creating a New Language Starter

To add support for a new language, create a script following this pattern:

### Script Template

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
Generate [Language] project starter files

.DESCRIPTION
Creates language-specific starter files for a [Language] project.
Called automatically by setup-project.ps1 if this script exists.

.PARAMETER ProjectPath
Project root directory.

.PARAMETER ProjectName
Project display name (used in configuration files).
#>

param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$ProjectName
)

# Import shared setup module functions
$modulePath = Join-Path $PSScriptRoot '..\modules\Setup.psm1'
Import-Module $modulePath -Force

Write-Step "Setting up [Language] starter files"

# ============================================================================
# Config File 1: [Description]
# ============================================================================

$content1 = @"
# Your configuration content here
"@

Set-Content -Path (Join-Path $ProjectPath 'config-file-1.ext') -Value $content1
Write-Success "Generated config-file-1.ext"

# ============================================================================
# Config File 2: [Description]
# ============================================================================

# ... create more files ...

Write-Success "[Language] starter setup complete"
```

### Naming Convention

- **Script name:** `setup-starter-<language>.ps1` where `<language>` matches the Language parameter value used in `setup-project.ps1`
  - Examples: `setup-starter-csharp.ps1`, `setup-starter-rust.ps1`, `setup-starter-go.ps1`

### File Organization

Each starter should typically generate:

1. **Build/Dependency Files**
   - `package.json` (Node)
   - `Cargo.toml` (Rust)
   - `setup.py` / `pyproject.toml` (Python)
   - `.csproj` (C#)
   - `pom.xml` (Java)
   - `go.mod` (Go)

2. **Config Files**
   - Linting: `.eslintrc`, `.pylintrc`, etc.
   - Formatting: `.prettierrc`, `black.toml`, etc.
   - Testing: `jest.config.js`, `pytest.ini`, etc.

3. **Source Stubs**
   - `src/index.js` or `src/main.rs` or `src/main.py`
   - Typical "Hello World" or starter code

4. **Test Stubs**
   - `tests/index.test.js` or equivalent
   - Demonstrates test structure

### Best Practices

1. **Use shared setup module functions**
   ```powershell
   $modulePath = Join-Path $PSScriptRoot '..\modules\Setup.psm1'
   Import-Module $modulePath -Force
   Write-Step, Write-Success, Write-WarningMessage
   ```

2. **Create directories first**
   ```powershell
   $srcDir = Join-Path $ProjectPath 'src'
   $null = New-Item -ItemType Directory -Path $srcDir -Force -ErrorAction SilentlyContinue
   ```

3. **Generate from templates**
   - Use here-strings (`@"..."@`) for multi-line content
   - Keep formatting clear and production-ready

4. **Report progress**
   - Call `Write-Success` after each file
   - Help users see what was created

5. **Handle errors gracefully**
   - Use `-ErrorAction SilentlyContinue` where appropriate
   - The orchestrator catches errors and reports them

### Example: C# Starter

```powershell
#Requires -Version 5.1
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$ProjectName
)

$modulePath = Join-Path $PSScriptRoot '..\modules\Setup.psm1'
Import-Module $modulePath -Force

Write-Step "Setting up C# starter files"

# .csproj
$csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net7.0</TargetFramework>
    <OutputType>Exe</OutputType>
    <RootNamespace>$ProjectName</RootNamespace>
  </PropertyGroup>
</Project>
"@
Set-Content -Path (Join-Path $ProjectPath "$ProjectName.csproj") -Value $csprojContent
Write-Success "Generated .csproj"

# Program.cs
$programContent = @"
namespace $ProjectName;

class Program
{
    static void Main()
    {
        Console.WriteLine("Welcome to $ProjectName");
    }
}
"@
Set-Content -Path (Join-Path $ProjectPath 'src/Program.cs') -Value $programContent
Write-Success "Generated Program.cs"

# ... more files ...

Write-Success "C# starter setup complete"
```

## Troubleshooting

### Starter Script Not Found

If `setup-starter-<language>.ps1` doesn't exist for your chosen language:
- The `setup-project.ps1` will skip language-specific setup
- You'll need to manually create language config files
- Consider creating the starter script using the template above

### Starter Script Fails

If a starter script errors during execution:
- The orchestrator catches and reports the error
- It continues with the rest of setup
- Check the error message for details
- Fix the starter script and re-run

## Extending for New Languages

To add support for another language:

1. **Create the starter script** using the template
2. **Name it** `setup-starter-<language>.ps1` where `<language>` matches a supported value in `setup-project.ps1`
3. **Add the language to** `setup-project.ps1` parameter validation if needed
4. **Test it:**
   ```powershell
   .\scripts\setup-project.ps1 -ProjectPath 'D:\Test\Project' -ProjectName 'Test' -Language '<language>'
   ```
5. **Document it** in this README

## References

- `scripts/modules/Setup.psm1` — Shared utility + core functions for file generation
- `scripts/setup-project.ps1` — Main orchestrator
- [Setup specification](../architecture/setup-specification.md) — Overall setup specification
