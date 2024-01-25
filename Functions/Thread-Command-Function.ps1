Function Thread-Command
{
	<#
	.SYNOPSIS
	    Runs a command against a list of computers.
	.PARAMETER Hosts
		The list of hosts to run command with.  Default is all domain hosts.
	.PARAMETER Command
		The string command to run against each host.  Include the $Computername variable ensuring that the "$" is escaped.
	.PARAMETER InitializationScript
		A script as a string to be run before the Command is executed.  Be sure to escape as well.
	.PARAMETER ReturnResults
		Specifies that the results of the command should be returned.  Results are returned as a HashTable of Computernames and results.
	.PARAMETER ReturnFailed
		Specifies that an array of computers on which the command failed should be returned.
	.NOTES
	    Name: Thread-Command
	    Author: Nick Walker
	.EXAMPLE
	Thread-Command -Command "Get-InstalledPrograms `$Computername | Where-Object {`$_.DisplayName -eq 'Triumfant Agent'}" -InitializationScript ". h:\code\scripts\powershell\functions\Get-InstalledPrograms-Function.ps1"

	Description
	-----------
	Runs a command against a list of computers.

	#>

	param
	(
		[Parameter(ValueFromPipeline = $True)]
		[String[]] $ComputerName = (List-DomainHosts -Names -Clients),
        [String] $Command,
        [String] $Title,
        [String] $InitializationScript,
        $Arguments,
        [switch] $ReturnResults,
        [switch] $ReturnFailed,
        [int] $Timeout = 600,
        [int] $Sender = 0
	)

	$ErrorActionPreference = "Silentlycontinue"

	$StartTime = Get-Date
	$ndx = 0
	$AllJobs = @{}
    $results = @{}
    $Failed = @()

	if (-not $Title)
    {
        $Title = "Running Commands $PrettyTime"
    }

    Register-EngineEvent -SourceIdentifier "RemoteProcess" -Forward
    foreach ($client in $ComputerName)
	{
        $CurrentCommand = $Command
        foreach ($Key in $Arguments.Keys)
        {
            $CurrentCommand = $CurrentCommand.Replace("`$$Key", $Arguments[$Key][$client])
        }
        $AllJobs.Add((Start-Job -ScriptBlock ([scriptblock]::Create($CurrentCommand.Replace('$ComputerName', $client))) -InitializationScript ([scriptblock]::Create($InitializationScript)) -Name $client), [Diagnostics.Stopwatch]::StartNew())
		
        $ndx++
		$CurTime = (New-TimeSpan $StartTime $(Get-Date))
		$TimePer = $CurTime.TotalSeconds / $ndx
		$PrettyTime = $CurTime.ToString("hh\:mm\:ss")
		Write-Progress -Activity $Title -Status "$client" -PercentComplete (($ndx / $ComputerName.Count) * 100) -SecondsRemaining ($TimePer * ($ComputerName.Count - $ndx))
        New-Event -SourceIdentifier "RemoteProcess" -MessageData "$Title|Running Command|$(($ndx / $ComputerName.Count) * 100)" -Sender $Sender > $null

		if ($ndx % 20 -eq 0)
        {
            $RunningJobs = Get-Job -Id ($AllJobs.Keys).Id | Where-Object{$_.State -eq "Running"}
		    if ($RunningJobs.Count -ge 20)
		    {
			    $completed = Wait-Job -Job $RunningJobs -Any -Timeout $Timeout
                foreach ($job in $RunningJobs)
                {
                    if ($AllJobs[$job].Elapsed.TotalSeconds -gt $Timeout)
                    {
                        Stop-Job $job
                    }
                }
		    }
        }
	}

    do
    {
        Write-Progress -Activity $Title -Status "Waiting for $($RemainingJobs.Count) remaining threads to complete"
        New-Event -SourceIdentifier "RemoteProcess" -MessageData "$Title|Waiting for $($RemainingJobs.Count) remaining threads to complete|100" -Sender $Sender > $null
        
        $completed = Wait-Job -Job -Any $RemainingJobs -Timeout $Timeout
        foreach ($job in $RemainingJobs)
        {
            if ($AllJobs[$job].Elapsed.TotalSeconds -gt $Timeout)
            {
                Stop-Job $job
            }
        }

    	$RemainingJobs = Get-Job -Id $AllJobs.Keys.Id | Where-Object{$_.State -eq "Running"}
    } while ($RemainingJobs.Count -gt 0)

	$ndx = 0
	Foreach ($singleJob in $AllJobs.Keys)
	{
        if ($singleJob.ChildJobs[0].Error.Count -gt 0 -or $singleJob.State -eq "Failed")
        {
            $Failed += $singleJob.Name
        }

		$results.Add($singleJob.Name, (Receive-Job -Job $singleJob))
        Remove-Job -Job $singleJob
		$ndx++
		Write-Progress -Activity $Title -Status "Compiling Results" -CurrentOperation $singleJob.Id -PercentComplete (($ndx / $AllJobs.Count) * 100)
        New-Event -SourceIdentifier "RemoteProcess" -MessageData "$Title|Compiling Results|$(($ndx / $AllJobs.Count) * 100)" -Sender $Sender > $null
	}
    
    if ($ReturnResults) {$results}
    elseif ($ReturnFailed) {$Failed}
}