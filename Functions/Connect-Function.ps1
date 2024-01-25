function Connect {
    param (
        $ComputerName,
        $ProfilePath
    )

    #clean out non-open connections 
    gsn | Where-Object {$_.state -ne "Opened"} | rsn 

    #Check for Open Sessions
    $Session = gsn | Where-Object {$_.computername -eq $ComputerName}
    if(-not $Session) {    
        $Session = New-PSSession $ComputerName
        Invoke-Command -Session $Session -ScriptBlock {
            $SessionConfig = Get-PSSessionConfiguration | ?{$_.Name -eq "Default"}
            if (-not $SessionConfig) {
                Register-PSSessionConfiguration -Name Default -StartupScript $ProfilePath
            }
        }
        Remove-PSSession $Session
    }
    Enter-PSSession -ComputerName $ComputerName -ConfigurationName Default
}