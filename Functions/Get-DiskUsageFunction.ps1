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

Function Get-DiskUsage
{
    Get-WmiObject Win32_LogicalDisk | select DeviceID,@{n="Size";e={GetHumanReadableSize $_.Size}},@{n="FreeSpace";e={GetHumanReadableSize $_.FreeSpace}}
}

Function Get-FolderSize
{
    param
    (
        [Parameter(ValueFromPipeline=$True)]
        [string[]]$Folder = "."
    )

    process
    {
        ls -Recurse $Folder | Measure-Object -Property Length -Sum | select @{n="Folder";e={$Folder}},@{n="Size";e={GetHumanReadableSize $_.Sum}}
    }
}