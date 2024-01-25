#usage: Test-UserCredential -username UserNameToTest -password (Read-Host)

Function Test-UserCredential { 
    Param(
        [PSCredential]$Credential = (Get-Credential)
    )

    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $opt = [System.DirectoryServices.AccountManagement.ContextOptions]::SimpleBind
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $ct
    $pc.ValidateCredentials($Credential.UserName, $t.GetNetworkCredential().Password).ToString()
} 