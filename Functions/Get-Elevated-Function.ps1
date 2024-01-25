Function Get-Elevated {
    $CurrentId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentPrinc = New-Object System.Security.Principal.WindowsPrincipal($CurrentId)
    $CurrentPrinc.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}