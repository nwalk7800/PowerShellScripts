Function global:Parse-SecLog
{
    param
    (
        [string] $PSLogListFile,
        [string] $EvtFile = "Security",
        [object[]] $EventLog,
        [string] $ComputerName = $env:COMPUTERNAME,
        [Hashtable] $ExcludeUsers = @{},
        [DateTime] $After = 0,
        [DateTime] $Before = (Get-Date)
    )

    if (-not $EventLog)
    {
        Write-Progress -Activity "Parsing Security Log" -CurrentOperation "Pulling Events" -PercentComplete 1

        if ($PSLogListFile)
        {
            $EventLog = Import-Csv $PSLogListFile -Header RecordId,LogName,ProviderName,KeywordsDisplayNames,MachineName,TimeCreated,Id,IDK,Message
        }
        else
        {
            $FilterXML = "<QueryList><Query Id='0' Path='$EvtFile'><Select Path='Security'>*"
            $FilterXML += "[System[(EventID=4624 or EventID=4634 or EventID=4647 or EventID=4688 or EventID=4608)"
            $FilterXML += " and TimeCreated[@SystemTime&gt;='$($After.ToUniversalTime().ToString("yyyy-MM-dd\THH:mm:ss.000\Z"))' and @SystemTime&lt;='$($Before.ToUniversalTime().ToString("yyyy-MM-dd\THH:mm:ss.000\Z"))']"
            $FilterXML += "]]</Select></Query></QueryList>"

            $EventLog = Get-WinEvent -ComputerName $ComputerName -FilterXml $FilterXML -Oldest
        }
    }

    $Sessions = @{}
    $Overview = @()
    $return = @()
    $reboots = 0
    $curEvent = 0

    foreach ($Event in $EventLog)
    {
        Write-Progress -Activity "Parsing Security Log" -CurrentOperation "Parsing Events" -PercentComplete ($curEvent / $EventLog.Count * 100)
        if ($Event.Id -eq "4624")
        {
            If ($Event.Message -match '(?sm)Logon Type:\s*(?<LogonType>.*?)\s*New Logon:\s*Security ID:\s*(?<Sid>S.*?)\s*Account Name:\s*(?<Username>.*?)\s*Account Domain:\s*(?<Domain>.*?)\s*Logon ID:\s*(?<LogonID>.*?)\s')
            {
                If ($Matches.Sid.Length -gt 10 -and $Matches.LogonType -eq "2" -and -not $ExcludeUsers.Contains($Matches.Username))
                {
                    If (-not $Sessions.ContainsKey("$($reboots)x$($Matches.LogonID)"))
                    {
                        $Sessions.Add("$($reboots)x$($Matches.LogonID)", @())
                    }
                    $Sessions["$($reboots)x$($Matches.LogonID)"] += "Logon $($Event.TimeCreated) $($Matches.Domain)\$($Matches.Username)"
                    $return += $Event
                }
            }
        }
        elseif ($Event.Id -eq "4634")
        {
            If ($Event.Message -match '(?sm)Subject:\s*Security ID:\s*(?<Sid>S.*?)\s*Account Name:\s*(?<Username>.*?)\s*Account Domain:\s*(?<Domain>.*?)\s*Logon ID:\s*(?<LogonID>.*?)\s*Logon Type:\s*(?<LogonType>.*?)\s')
            {
                If ($Sessions.ContainsKey("$($reboots)x$($Matches.LogonID)"))
                {
                    $Sessions["$($reboots)x$($Matches.LogonID)"] += "Logoff $($Event.TimeCreated) $($Matches.Domain)\$($Matches.Username)"
                    $return += $Event
                }
            }
        }
        elseif ($Event.Id -eq "4647")
        {
            If ($Event.Message -match '(?sm)Subject:\s*Security ID:\s*(?<Sid>S.*?)\s*Account Name:\s*(?<Username>.*?)\s*Account Domain:\s*(?<Domain>.*?)\s*Logon ID:\s*(?<LogonID>.*?)\s')
            {
                If ($Sessions.ContainsKey("$($reboots)x$($Matches.LogonID)"))
                {
                    $Sessions["$($reboots)x$($Matches.LogonID)"] += "Logoff $($Event.TimeCreated) $($Matches.Domain)\$($Matches.Username)"
                    $return += $Event
                }
            }
        }
        elseif ($Event.Id -eq "4688")
        {
            If ($Event.Message -match '(?sm)Subject:.*?Security ID:\s*(?<Sid>S.*?)\sAccount Name:\s*(?<Username>.*?)\s*Account Domain:\s*(?<Domain>.*?)\s*Logon ID:\s*(?<LogonID>.*?)\s.*New Process Name:\s*(?<ProcessName>.*?)$')
            {
                If ($Sessions.ContainsKey("$($reboots)x$($Matches.LogonID)"))
                {
                    $Sessions["$($reboots)x$($Matches.LogonID)"] += "Process $($Event.TimeCreated) $($Matches.ProcessName)"
                    $return += $Event
                }
            }
        }
        elseif ($Event.Id -eq "4608")
        {
            $reboots++
        }
    }
    Write-Progress -Activity "Parsing Security Log" -CurrentOperation "Writing Output" -PercentComplete ($curEvent / $EventLog.Count * 100)
    $return | Export-Csv -Path out.csv
    echo "" > sessions.csv
    $Sessions.Keys | %{$_ >> sessions.csv; $Sessions.Item("$_") >> sessions.csv}
}