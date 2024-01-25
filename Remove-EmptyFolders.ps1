function Remove-EmptyFolders
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        $SearchRoot
    )

    try
    {
        $FullNames = ls $SearchRoot -Directory
        if ($FullNames.Count -gt 0 )
        {
            $ToDelete = $FullNames | ?{(ls $_ -Recurse -Exclude Thumbs.db -File) -eq $null}
            foreach ($Folder in $ToDelete)
            {
                if ($PSCmdlet.ShouldProcess($Folder, "Remove Folder"))
                {
                    Write-Verbose "Removing Folder: $Folder"
                    $Folder | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch
    {
        WriteOut "Unable to access path: $SearchRoot" -Type Error
    }
}