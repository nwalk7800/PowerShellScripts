Add-Type -TypeDefinition @"
    public enum TaskState
    {
        Unknown = 0,
        Disabled = 1,
        Queued = 2,
        Ready = 3,
        Running = 4
    }
"@

Function global:Add-ScheduledTask
{
    param
    (
        [string] $ComputerName = $env:COMPUTERNAME,
        [string] $Folder = "\",
        [string] $Name,
        [string] $Path,
        [string] $Arguments
    )

    #$Jobs += Start-Job -Name $Computer -ScriptBlock ([scriptblock]::Create("([WMICLASS]`"\\$Computer\ROOT\CIMV2:Win32_ScheduledJob`").Create(`"$($CommandLine.Replace('"','""""').Replace('$','`$')) > $StdOutFile`",((Get-Date).AddMinutes(1.1).ToString(`"yyyyMMddHHmm00.000000`$([System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes)`"))) 2> `$null"))

    $Schedule = New-Object -ComObject ("Schedule.Service")
    try{$Schedule.Connect($ComputerName)}catch{}

    if ($Schedule.Connected)
    {
        $TaskFolder = $Schedule.GetFolder($Folder)
        $Task = $Schedule.NewTask(0)
        
        $Task.Principal.LogonType = 5
        $Task.Principal.RunLevel = 1

        $Trigger = $Task.Triggers.Create(1)
        $Trigger.StartBoundary = (Get-Date).AddSeconds(5).ToString("yyyy-MM-ddTHH:mm:ss")
        $Trigger.ExecutionTimeLimit = "PT5M"

        $Action = $Task.Actions.Create(0)
        $Action.Path = $Path
        $Action.Arguments = $Arguments
        
        $TaskFolder.RegisterTaskDefinition($Name, $task, 6, "system", $null, 5)
    }
}

Function global:Remove-ScheduledTask
{
    param
    (
        [string] $ComputerName = $env:COMPUTERNAME,
        [string[]] $Name,
        [string] $XmlText,
        [switch] $RootFolder
    )

    $Schedule = New-Object -ComObject ("Schedule.Service")
    try{$Schedule.Connect($ComputerName)}catch{}
    
    if ($Schedule.Connected)
    {
        $AllFolders = Get-AllTaskSubFolders -RootFolder:$RootFolder -Schedule $Schedule
        foreach ($Folder in $AllFolders)
        {
            if (($Tasks = $Folder.GetTasks(0)))
            {
                Foreach ($Task in $Tasks)
                {
                    if ($Name)
                    {
                        if ($Task.Name -in $Name)
                        {
                            $Task.Stop(0)
                            $Folder.DeleteTask($Task.Name,0)
                        }
                    }
                    elseif ($XmlText)
                    {
                        if ($Task.Definition.XmlText.Contains($XmlText))
                        {
                            $Task.Stop(0)
                            $Folder.DeleteTask($Task.Name,0)
                        }
                    }

                }
            }
        }
    }
}

Function global:Get-AllTaskSubFolders
{
    param
    (
        # Set to use $Schedule as default parameter so it automatically list all files
        # For current schedule object if it exists.
        [System.__ComObject] $Schedule,
        [System.__ComObject] $FolderRef = $Schedule.getfolder("\"),
        [switch] $RootFolder
    )

    if ($RootFolder)
    {
        $FolderRef
    }
    else
    {
        $FolderRef
        $ArrFolders = @()
        if(($folders = $FolderRef.getfolders(1)))
        {
            foreach ($folder in $folders)
            {
                $ArrFolders += $folder
                if($folder.getfolders(1))
                {
                    Get-AllTaskSubFolders -FolderRef $folder
                }
            }
        }
        $ArrFolders
    }
}

Function global:Get-ScheduledTasks
{
    param
    (
        [string] $ComputerName = $env:COMPUTERNAME,
        [switch] $RootFolder
    )

    $Schedule = New-Object -ComObject ("Schedule.Service")
    try{$Schedule.Connect($ComputerName)}catch{}

    if ($Schedule.Connected)
    {
        $AllFolders = Get-AllTaskSubFolders -RootFolder:$RootFolder -Schedule $Schedule
        foreach ($Folder in $AllFolders)
        {
            if (($Tasks = $Folder.GetTasks(0)))
            {
                Foreach ($Task in $Tasks)
                {
                    New-Object -TypeName PSCustomObject -Property @{
                        ComputerName = $ComputerName
                        Name = $Task.Name
                        Path = $Task.Path
                        State = [TaskState]$Task.State
                        LastRunTime = $Task.LastRunTime
                        NextRunTime = $Task.NextRunTime
                        ComObject = $Task
                        ActionType = ([xml]$Task.Xml).Task.Actions.FirstChild.Name
                        Action = (Get-TaskAction -Task $Task -ComputerName $ComputerName)
                    }
                }
            }
        }
    }
}

Function global:Get-TaskAction
{
    param
    (
        [Parameter(Mandatory=$True)]
        [System.__ComObject] $Task,
        [string] $ComputerName = $env:COMPUTERNAME
    )

    $Type = ([xml]$Task.Xml).Task.Actions.FirstChild.Name
    $Action = ([xml]$Task.Xml).Task.Actions.FirstChild.InnerText

    if ($Type -eq "ComHandler")
    {
        $Action -match "\{.*?\}" | Out-Null
        
        $Temp = (Get-RegistryKey -ComputerName $ComputerName -KeyPath "HKLM:\SOFTWARE\Classes\CLSID\{FF87090D-4A9A-4f47-879B-29A80C355D61}\InprocServer32\" -Property "(Default)" -NoProgress).Value
        if ($Temp)
        {
            $Action = $Temp
        }
    }
    $Action
}

Function global:Parse-XMLObject
{
    param
    (
        [Parameter(Mandatory=$True)]
        [Object] $Node
    )
    
    $return = New-Object PSCustomObject 

    foreach ($Element in $Node.ChildNodes)
    {
        if ($Element.ChildNodes[0].NodeType -eq [System.Xml.XmlNodeType]::Element)
        {
            $return | Add-Member -MemberType NoteProperty -Name $Element.Name -Value (Parse-XMLObject -Node $Element)
        }
        else
        {
            $return | Add-Member -MemberType NoteProperty -Name $Element.Name -Value $Element.InnerText
        }
    }
    $return
}