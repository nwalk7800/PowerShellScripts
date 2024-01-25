param (
    $Path = $PSScriptRoot
)

Function GetHumanReadableSize
{
    Param
    (
        $Bytes
    )

    if ($Bytes -ge 1TB){$Divisor = 1TB; $Unit = "TB"}
    elseif ($Bytes -ge 1GB){$Divisor = 1GB; $Unit = "GB"}
    elseif ($Bytes -ge 1MB){$Divisor = 1MB; $Unit = "MB"}
    elseif ($Bytes -ge 1KB){$Divisor = 1KB; $Unit = "KB"}
    else {$Divisor = 1; $Unit = "B"}

    "{0:N2}" -f ($Bytes / $Divisor) + "$Unit"
}

$All = @()
foreach ($Folder in (ls $Path)) {
    $All += Get-ChildItem $Folder -Recurse | Measure-Object -Property Length -Sum |  select @{n="Name";e={$Folder.Name}},Sum
}

$All | sort Sum | select Name,@{n="Size";e={GetHumanReadableSize $_.Sum}} | ft -AutoSize