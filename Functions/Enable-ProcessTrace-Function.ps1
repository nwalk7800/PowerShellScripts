function Enable-ProcessTrace
{
    $Query = "Select * From __InstanceCreationEvent within 3 where TargetInstance ISA 'Win32_Process'"
    $Identifier = "StartProcess"
    $ActionBlock = {
        $e = $Event.SourceEventArgs.NewEvent.TargetInstance
        Write-Host ("Process {0} with PID {1} has started" -f $e.Name, $e.ProcessID)
    }
    Register-WmiEvent -Query $Query -SourceIdentifier $Identifier -Action $ActionBlock
}

function Start-ProcessTrace
{
    try
    {
        $Event = Enable-ProcessTrace

        while ($true){Start-Sleep -Seconds 1}
    }
    finally
    {
        Get-EventSubscriber -SourceIdentifier "StartProcess" | Unregister-Event
    }

}