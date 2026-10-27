#Requires -Version 7.4
# A deliberately bounded TOML subset, not a general TOML implementation. Unsupported
# syntax rejects the entire input; nothing outside mcp_servers is silently skipped.
# State is local to one parse. Only the existing auditor is exported by its module.
function ConvertFrom-McpAuditToml {
    param([string]$Text)
    $state = @{ Text = $Text; Offset = 0; Nodes = 0; Tables = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal) }

    function Get-TomlCharacter {
        if ($state.Offset -ge $state.Text.Length) { return [char]0 }
        return $state.Text[$state.Offset]
    }
    function Skip-TomlSpace {
        param([switch]$Newlines)
        # Character arrays avoid PowerShell's cultural string membership, which
        # treats some Unicode spaces as ASCII whitespace. TOML does not.
        while ($state.Offset -lt $state.Text.Length) {
            $character = Get-TomlCharacter
            if ($character -in [char[]]@(' ', "`t") -or ($Newlines -and $character -in [char[]]@("`r", "`n"))) { $state.Offset++; continue }
            if ($Newlines -and $character -eq '#') {
                while ($state.Offset -lt $state.Text.Length -and (Get-TomlCharacter) -notin [char[]]@("`r", "`n")) { $state.Offset++ }
                continue
            }
            break
        }
    }
    function Read-TomlString {
        $quote = Get-TomlCharacter
        $state.Offset++
        if ($state.Offset + 1 -lt $state.Text.Length -and $state.Text[$state.Offset] -eq $quote -and $state.Text[$state.Offset + 1] -eq $quote) { throw 'Multiline strings are outside the audit grammar.' }
        $builder = [System.Text.StringBuilder]::new()
        while ($state.Offset -lt $state.Text.Length) {
            $character = Get-TomlCharacter
            $state.Offset++
            if ($character -eq $quote) { return $builder.ToString() }
            if ([int]$character -lt 32 -and $character -ne "`t" -or [int]$character -eq 127) { throw 'Control character in string.' }
            if ($quote -eq '"' -and $character -eq '\') {
                $escape = Get-TomlCharacter
                $state.Offset++
                switch -CaseSensitive ($escape) {
                    'b' { $character = [char]8 }
                    't' { $character = "`t" }
                    'n' { $character = "`n" }
                    'f' { $character = [char]12 }
                    'r' { $character = "`r" }
                    '"' { $character = '"' }
                    '\' { $character = '\' }
                    { $_ -cin @('u', 'U') } {
                        $length = if ($escape -ceq 'u') { 4 } else { 8 }
                        if ($state.Offset + $length -gt $state.Text.Length) { throw 'Incomplete Unicode escape.' }
                        $digits = $state.Text.Substring($state.Offset, $length)
                        if ($digits -cnotmatch '^[0-9A-Fa-f]+$') { throw 'Invalid Unicode escape.' }
                        $code = [Convert]::ToUInt32($digits, 16)
                        if ($code -gt 0x10FFFF -or ($code -ge 0xD800 -and $code -le 0xDFFF)) { throw 'Invalid Unicode scalar.' }
                        $character = [char]::ConvertFromUtf32([int]$code)
                        $state.Offset += $length
                    }
                    default { throw 'Unsupported string escape.' }
                }
            }
            [void]$builder.Append($character)
        }
        throw 'Unterminated string.'
    }
    function Read-TomlKey {
        $parts = [System.Collections.Generic.List[string]]::new()
        do {
            Skip-TomlSpace
            if ((Get-TomlCharacter) -in [char[]]@('"', "'")) { $part = Read-TomlString }
            else {
                $start = $state.Offset
                while ((Get-TomlCharacter) -cmatch '^[A-Za-z0-9_-]$') { $state.Offset++ }
                if ($start -eq $state.Offset) { throw 'Missing key.' }
                $part = $state.Text.Substring($start, $state.Offset - $start)
            }
            $parts.Add($part)
            if ($parts.Count -gt 64) { throw 'Key nesting limit.' }
            Skip-TomlSpace
            if ((Get-TomlCharacter) -ne '.') { break }
            $state.Offset++
        } while ($true)
        return ,$parts.ToArray()
    }
    function Get-TomlPathId {
        param([string[]]$Parts)
        # Length prefixes keep quoted dots and other punctuation distinct.
        return (($Parts | ForEach-Object { "$($_.Length):$_" }) -join '')
    }
    function Get-TomlEmptyTable {
        return ,([System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal))
    }
    function Add-TomlEntry {
        param([System.Collections.IDictionary]$Table, [string[]]$Parts, [object]$Value, [string[]]$Prefix)
        if ($Prefix.Count + $Parts.Count -gt 64) { throw 'Table nesting limit.' }
        $node = $Table
        for ($i = 0; $i -lt $Parts.Count - 1; $i++) {
            $path = Get-TomlPathId (@($Prefix) + @($Parts[0..$i]))
            if (!$node.Contains($Parts[$i])) {
                $node.Add($Parts[$i], (Get-TomlEmptyTable))
                $state.Tables[$path] = 'dotted'
            }
            elseif ($node[$Parts[$i]] -isnot [System.Collections.IDictionary] -or !$state.Tables.ContainsKey($path) -or $state.Tables[$path] -ne 'dotted') { throw 'Conflicting key.' }
            $node = $node[$Parts[$i]]
        }
        $key = $Parts[-1]
        if ($node.Contains($key)) { throw 'Duplicate key.' }
        $node.Add($key, $Value)
        if ($Value -is [System.Collections.IDictionary]) { $state.Tables[(Get-TomlPathId (@($Prefix) + @($Parts)))] = 'inline' }
    }
    function Read-TomlValue {
        param([int]$Depth = 0)
        $state.Nodes++
        if ($Depth -gt 64 -or $state.Nodes -gt 65536) { throw 'Value complexity limit.' }
        Skip-TomlSpace
        $character = Get-TomlCharacter
        if ($character -in [char[]]@('"', "'")) { return Read-TomlString }
        if ($character -eq '[') {
            $state.Offset++
            $values = [System.Collections.Generic.List[object]]::new()
            Skip-TomlSpace -Newlines
            while ((Get-TomlCharacter) -ne ']') {
                $values.Add((Read-TomlValue ($Depth + 1)))
                Skip-TomlSpace -Newlines
                if ((Get-TomlCharacter) -eq ']') { break }
                if ((Get-TomlCharacter) -ne ',') { throw 'Missing array separator.' }
                $state.Offset++
                Skip-TomlSpace -Newlines
            }
            $state.Offset++
            return ,$values.ToArray()
        }
        if ($character -eq '{') {
            $state.Offset++
            $table = Get-TomlEmptyTable
            Skip-TomlSpace
            if ((Get-TomlCharacter) -ne '}') {
                do {
                    $parts = Read-TomlKey
                    if ($parts.Count -ne 1) { throw 'Dotted inline keys are outside the audit grammar.' }
                    if ((Get-TomlCharacter) -ne '=') { throw 'Missing assignment.' }
                    $state.Offset++
                    $value = Read-TomlValue ($Depth + 1)
                    # Inline table paths are isolated from the document table registry.
                    $savedTables = $state.Tables
                    $state.Tables = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
                    try { Add-TomlEntry $table $parts $value @() }
                    finally { $state.Tables = $savedTables }
                    Skip-TomlSpace
                    if ((Get-TomlCharacter) -eq '}') { break }
                    if ((Get-TomlCharacter) -ne ',') { throw 'Missing inline table separator.' }
                    $state.Offset++
                } while ($true)
            }
            $state.Offset++
            return ,$table
        }
        $start = $state.Offset
        while ($state.Offset -lt $state.Text.Length -and (Get-TomlCharacter) -notin [char[]]@(' ', "`t", "`r", "`n", '#', ',', ']', '}')) { $state.Offset++ }
        $token = $state.Text.Substring($start, $state.Offset - $start)
        if ([StringComparer]::Ordinal.Equals($token, 'true')) { return $true }
        if ([StringComparer]::Ordinal.Equals($token, 'false')) { return $false }
        # Numeric values are only structural data, never launch strings. Constrain
        # syntax before converting; overflow/unsupported dates fail the whole file.
        if ($token -cmatch '^[+-]?(?:0|[1-9](?:_?[0-9])*)$') { return [long]::Parse($token.Replace('_', ''), [Globalization.CultureInfo]::InvariantCulture) }
        if ($token -cmatch '^[+-]?(?:0|[1-9](?:_?[0-9])*)(?:\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?|[eE][+-]?[0-9](?:_?[0-9])*)$') {
            return [double]::Parse($token.Replace('_', ''), [Globalization.CultureInfo]::InvariantCulture)
        }
        throw 'Unsupported value.'
    }

    if ($Text -match "(?<!`r)`r(?!`n)|[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]") { throw 'Unsupported control character.' }
    $root = Get-TomlEmptyTable
    $current = $root
    [string[]]$prefix = @()
    while ($state.Offset -lt $Text.Length) {
        Skip-TomlSpace -Newlines
        if ($state.Offset -ge $Text.Length) { break }
        if ((Get-TomlCharacter) -eq '[') {
            $state.Offset++
            $prefix = Read-TomlKey
            if ((Get-TomlCharacter) -ne ']') { throw 'Unsupported table header.' }
            $state.Offset++
            $current = $root
            for ($i = 0; $i -lt $prefix.Count; $i++) {
                $id = Get-TomlPathId $prefix[0..$i]
                if (!$current.Contains($prefix[$i])) {
                    $current.Add($prefix[$i], (Get-TomlEmptyTable))
                    $state.Tables[$id] = 'implicit'
                }
                if ($current[$prefix[$i]] -isnot [System.Collections.IDictionary] -or $state.Tables[$id] -eq 'inline') { throw 'Conflicting table.' }
                if ($i -eq $prefix.Count - 1) {
                    if ($state.Tables[$id] -ne 'implicit') { throw 'Duplicate table.' }
                    $state.Tables[$id] = 'explicit'
                }
                $current = $current[$prefix[$i]]
            }
        }
        else {
            $parts = Read-TomlKey
            if ((Get-TomlCharacter) -ne '=') { throw 'Missing assignment.' }
            $state.Offset++
            $value = Read-TomlValue ($prefix.Count + $parts.Count)
            Add-TomlEntry $current $parts $value $prefix
        }
        Skip-TomlSpace
        if ((Get-TomlCharacter) -eq '#') {
            while ($state.Offset -lt $Text.Length -and (Get-TomlCharacter) -notin [char[]]@("`r", "`n")) { $state.Offset++ }
        }
        if ($state.Offset -lt $Text.Length -and (Get-TomlCharacter) -notin [char[]]@("`r", "`n")) { throw 'Trailing statement data.' }
    }
    return ,$root
}
