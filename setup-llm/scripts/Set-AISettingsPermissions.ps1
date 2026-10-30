#Requires -Version 7.0
<#
.SYNOPSIS
Applies Windows permissions for the AI settings engine's private staging files.
.DESCRIPTION
Internal adapter for .NET's Windows access-control APIs. Paths arrive through
the child environment, never interpolated into PowerShell source. The engine
validates their sandbox before invoking this adapter. No file content is read.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('PrivateDirectory', 'CopyDacl')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'
try {
    if (-not $IsWindows) { throw 'Windows permissions adapter required.' }
    $destination = $env:AI_SETTINGS_ACL_PATH
    if ($Mode -eq 'PrivateDirectory') {
        $acl = [System.Security.AccessControl.DirectorySecurity]::new()
        $acl.SetAccessRuleProtection($true, $false)
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
        [System.IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($destination), $acl)
    }
    else {
        $source = Get-Acl -LiteralPath $env:AI_SETTINGS_ACL_SOURCE
        $acl = [System.Security.AccessControl.FileSecurity]::new()
        $sections = [System.Security.AccessControl.AccessControlSections]::Access
        $acl.SetSecurityDescriptorSddlForm($source.GetSecurityDescriptorSddlForm($sections), $sections)
        [System.IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($destination), $acl)
    }
    exit 0
}
catch {
    # Never emit identities, paths, ACLs or arbitrary exception diagnostics.
    exit 1
}
