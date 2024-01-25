Function Test-FileLock
{
    param
    (
        [string[]] $Path,
        [switch] $Quiet
    )

    if ($Path)
    {
        $filepath = gi $(Resolve-Path $Path) -Force
    }
    else
    {
        $filepath = gi $_.fullname -Force
    }

    if ($filepath.psiscontainer) {return}
    
    $locked = $false
    trap
    {
        Set-Variable -Name locked -Value $true -Scope 1
        continue
    }

    $inputStream = New-Object system.IO.StreamReader $filepath
    if ($inputStream)
    {
        $inputStream.Close()
    }
    
    if ($Quiet)
    {
        $locked
    }
    else
    {
        @{$filepath = $locked}
    }
}