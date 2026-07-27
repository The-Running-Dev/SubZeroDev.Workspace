# Invoke-SetupProject

Runs the discovered PowerShell script 'scripts/setup-project.ps1'.

## Syntax

```powershell
Invoke-SetupProject -ProjectPath <String> -ProjectName <String> -Language <String> [-Client <String>] [-GitUserName <String>] [-GitUserEmail <String>] [-SkipGit <switch>] [-SkipLanguageStarter <switch>] [-SkipValidation <switch>] [-AutoCommit <switch>] [<CommonParameters>]
```

## Description

Scaffolded from 'scripts/setup-project.ps1'. Review its container invocation mappings before publishing.

## Parameters

### `-ProjectPath`

Type: `String`  
Required: Yes

Discovered from ProjectPath.

### `-ProjectName`

Type: `String`  
Required: Yes

Discovered from ProjectName.

### `-Language`

Type: `String`  
Required: Yes

Discovered from Language.

### `-Client`

Type: `String`  
Required: No

Discovered from Client.

### `-GitUserName`

Type: `String`  
Required: No

Discovered from GitUserName.

### `-GitUserEmail`

Type: `String`  
Required: No

Discovered from GitUserEmail.

### `-SkipGit`

Type: `switch`  
Required: No

Discovered from SkipGit.

### `-SkipLanguageStarter`

Type: `switch`  
Required: No

Discovered from SkipLanguageStarter.

### `-SkipValidation`

Type: `switch`  
Required: No

Discovered from SkipValidation.

### `-AutoCommit`

Type: `switch`  
Required: No

Discovered from AutoCommit.
