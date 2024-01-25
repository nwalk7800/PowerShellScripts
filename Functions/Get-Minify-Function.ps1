#TODO
#remove unneeded CommandParameters

function Get-Minified
{
    param
    (
        [Parameter(Position=0,ParameterSetName='File')]
        [string] $ScriptPath,
        [Parameter(ParameterSetName='Content')]
        $ScriptContent,
        [switch] $Measure,
        [string] $OutPath
    )

    function GetVariableName
    {
        param
        (
            [int] $VarNum,
            [switch] $Function
        )

        $VarName = ""
        $Chars = @()
        97..122 | %{$Chars += [char]$_}
        
        if (-not $Function)
        {
            0..9 | %{$Chars += $_}
        }

        while ($VarNum -gt $Chars.Count-1)
        {
            $VarNum = $VarNum - $Chars.Count
            $VarName += $Chars[$Chars.Count-1]
        }
        $VarName += $Chars[$VarNum]
        
        if ((-not (Get-Alias $VarName -ErrorAction SilentlyContinue)) -or (-not $Function))
        {
            $VarName
        }
    }

    function ShortenFlag
    {
        param
        (
            [string] $Command,
            [string] $Flag
        )

        $AllFlags = (Get-Command $Command -ErrorAction SilentlyContinue).Parameters.Keys

        if ($AllFlags)
        {
            $ndx = 0
            do
            {
                $ndx++
                $MatchingFlags = $AllFlags | ?{$_ -match "^" + $Flag.Substring(1,$ndx)}
            }
            while (($MatchingFlags.Count -gt 1) -and ($ndx -lt $Flag.Length-1))
        
            "-" + $Flag.Substring(1,$ndx)
        }
    }

    function Reassemble
    {
        param
        (
            $Tokenized
        )

        $Script = ""
        $Previous = ";"
        $CurrentVariable = 0
        $CurrentFunction = 0
        $StatementType = New-Object System.Collections.Stack
        $Reserved = @('$', '?', '^', '_', 'Args', 'ConsoleFileName', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'False', 'ForEach', 'Home', 'Host', 'Input', 'LastExitCode', 'Matches', 'MyInvocation', 'NextedPromptLevel', 'null', 'OFS', 'PID', 'Profile', 'PSBoundParameters', 'PsCmdlet', 'PSCommandPath', 'PsCulture', 'PSDebugContext', 'PsHome', 'PSItem', 'PSScriptRoot', 'PSSenderInfo', 'PsUICulture', 'PsVersionTable', 'Pwd', 'ReportErrorShowExceptionClass', 'ReportErrorShowInnerException', 'ReportErrorShowSource', 'ReportErrorShowStackTrace', 'Sender', 'ShellID', 'StackTrace', 'This', 'True')
        $RequiresSpace = @("Command","CommandParameter", "CommandArgument")
        $NoSpace = @("GroupStart","GroupEnd","Operator","NewLine","Type","StatementSeparator")
        $Specials = @{"`0"='`0';"`a"='`a';"`b"='`b';"`f"='`f';"`n"='`n';"`r"='`r';"`t"='`t';"`v"='`v'}
        $Variables = @{}
        $Aliases = @{}
        $Functions = @{}

        foreach ($Alias in (Get-Alias | select Name,ReferencedCommand | ?{$_.ReferencedCommand}))
        {
            $Command = $Alias.ReferencedCommand.Name
            if ($Aliases.ContainsKey($Command))
            {
                if ($Alias.Name.Length -lt $Aliases[$Command].Length)
                {
                    $Aliases.Add($Aliases[$Command], $Alias.Name)
                    $Aliases[$Command] = $Alias.Name
                }
                $Aliases.Add($Alias.Name, $Aliases[$Command])
            }
            else
            {
                $Aliases.Add($Command, $Alias.Name)
            }
        }

        foreach ($Token in $Tokenized)
        {
            if ($Token.content -eq "Sync" -and $Token.Type -ne "Variable")
            {
                Write-Host
            }

            $CurStatement = ""
            $Add = $true

            switch ($Token.Type)
            {
                "CommandParameter"
                {
                    if ($Functions.ContainsKey($CurrentCommand))
                    {
                        $Script += " -" + $Variables[$Token.Content.Substring(1)].Substring(1)
                    }
                    else
                    {
                        $Script += " " + (ShortenFlag -Command $CurrentCommand -Flag $Token.Content)
                    }
                }
                "CommandArgument"
                {
                    if ($Previous.Content -eq "function")
                    {
                        $StatementType.Push("Function")
                        if (-not $Functions.ContainsKey($Token.Content))
                        {
                            if ($Token.Content -match ":")
                            {
                                $Functions.Add($Token.Content, $Token.Content)
                            }
                            else
                            {
                                while (-not (GetVariableName $CurrentFunction -Function)){$CurrentFunction++}
                                $Functions.Add($Token.Content, (GetVariableName $CurrentFunction -Function))
                                $CurrentFunction++
                            }
                        }
                        $Script += " " + $Functions[$Token.Content]
                    }
                    elseif ($Token.Content -match '\$[a-z0-9_]+')
                    {
                        $cmd = $Token.Content
                        foreach ($variable in $Variables.Keys)
                        {
                            $cmd = $cmd -replace "\`$$variable",$Variables[$variable]
                        }
                        $script += ' ' + $cmd
                    }
                    elseif ($Previous.Content -eq ",")
                    {
                        $Script += $Token.Content
                    }
                    else
                    {
                        $Script += " " + $Token.Content
                    }
                }
                "GroupStart"
                {
                    switch ($Token.Content)
                    {
                        "{"{$StatementType.Push("Brace")}
                        "@{"{$StatementType.Push("Hash")}
                        "("
                        {
                            if ($Previous.Content -eq "for")
                            {
                                $StatementType.Push("For")
                            }
                            elseif ($Previous.Content -eq "Parameter")
                            {
                                $StatementType.Push("Parameter")
                            }
                            elseif ($Previous.Content -eq "CmdletBinding")
                            {
                                $StatementType.Push("CmdletBinding")
                            }
                            elseif ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Param"){}
                            else
                            {
                                $StatementType.Push("Paren")
                            }
                        }
                        '$('
                        {
                            if ($Previous.Type -eq "Keyword")
                            {
                                $Script += ' '
                            }
                            $StatementType.Push("Paren")
                        }
                        "@("{$StatementType.Push("Array")}
                    }
                    if ($Token.Content.Substring(0,1) -eq '@')
                    {
                        if ($Previous.Type -ne "Operator")
                        {
                            $Script += ' '
                        }
                    }
                    $Script += $Token.Content
                }
                "GroupEnd"
                {
                    switch ($Token.Content)
                    {
                        "}"
                        {
                            while($StatementType.Peek() -notin @("Brace","Hash","Switch","Param","TryCatch"))
                            {
                                if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                            }
                            if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                            
                            if ($StatementType.Count -gt 0 -and $StatementType.Peek() -in @("Function","Switch","Param","TryCatch"))
                            {
                                [void]$StatementType.Pop()
                            }
                        }
                        ")"
                        {
                            while($StatementType.Peek() -notin @("Param","Paren","Array","For","Parameter","CmdletBinding"))
                            {
                                if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                            }
                            if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                        }
                    }
                    if ($Script.Substring(($Script.Length-1)) -eq ";")
                    {
                        $Script = $Script.Substring(0,($Script.Length-1))
                    }
                    $Script += $Token.Content
                }
                {$_ -in "Keyword","Number","String","Variable","Command"}
                {
                    if ($Previous.Type -and $NoSpace -notcontains $Previous.Type)
                    {
                        $Script += " "
                    }
                }
                "Keyword"
                {
                    $Script += $Token.Content
                    if ($Token.Content -eq "Switch")
                    {
                        $StatementType.Push("Switch")
                    }
                    elseif ($Token.Content -eq "param")
                    {
                        $StatementType.Push("Param")
                    }
                    elseif ($Token.Content -in @("Try","Catch","Finally","Trap"))
                    {
                        $StatementType.Push("TryCatch")
                    }
                }
                "Number"
                {
                    if ($Previous.Type -eq "Operator" -and $Previous.Content -match "^-[a-z]+")
                    {
                        $Script += ' '
                    }
                    $Script += $Token.Content
                }
                "String"
                {
                    $String =  ($ScriptContent[$Token.Start..($Token.Start + $Token.Length - 1)]) -join ''
                    if ($String.Substring(0,1) -notin @("@", "'"))
                    {
                        foreach ($Special in $Specials.Keys)
                        {
                            $String = $String -replace $Special,$Specials[$Special]
                        }

                        foreach ($Variable in ($Variables.Keys | sort -Property Length -Descending))
                        {
                            $String = $String -replace "`$$Variable",$Variables[$Variable]
                        }
                    }
                    elseif ($String.Substring(0,1) -eq "@")
                    {
                        $String += "`n"
                    }
                    
                    if ($Previous.Type -eq "Operator" -and $Previous.Content -match "^-[a-z]+")
                    {
                        $Script += ' '
                    }
                    $Script += $String
                }
                "Variable"
                {
                    if ($Previous.Type -eq "Operator" -and $Previous.Content -match "^-[a-z]+")
                    {
                        $Script += ' '
                    }
                    
                    if ($Reserved -notcontains $Token.Content)
                    {
                        if (-not $Variables.ContainsKey($Token.Content))
                        {
                            if ($Token.Content -match "global:")
                            {
                                $Variables.Add($Token.Content, '$' + $Token.Content)
                            }
                            else
                            {
                                $Variables.Add($Token.Content, "`$$(GetVariableName $CurrentVariable)")
                                $CurrentVariable++
                            }
                        }
                        $Script += $Variables[$Token.Content]
                    }
                    else
                    {
                        $Script += '$' + $Token.Content
                    }
                }
                "Command"
                {
                    $Command = $Token.Content
                    $CurrentCommand = $Command
                    if ($Aliases.ContainsKey($Command))
                    {
                        $Command = $Aliases[$Command]
                    }
                    elseif ($Functions.ContainsKey($Command))
                    {
                        $Command = $Functions[$Command]
                        $StatementType.Push($Command)
                    }
                    if (-not ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign"))
                    {
                        $StatementType.Push("Assign")
                    }
                    $Script += $Command
                }
                {$_ -in @("StatementSeparator","NewLine")}
                {
                    if ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "For")
                    {
                        $Script += ";"
                    }
                    if ($StatementType.ToArray()[1] -in @("Switch","Parameter","CmdletBinding","Param") -or `
                        $Previous.Content -in @("param","else","try","begin","process","end","default","do") -or `
                        ($StatementType.Count -gt 0 -and $StatementType.Peek() -in @("Function","TryCatch","Param"))
                       ){}
                    elseif ($Script[-2..-1] -join '' -eq "@`n"){}
                    elseif ($Previous.Type -notin @("StatementSeparator","NewLine","Comment","GroupStart","GroupEnd","Operator"))
                    {
                        $Script += ";"
                        if ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                        {
                            if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                        }
                    }
                    elseif ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                    {
                        $Script += ";"
                        while ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                        {
                            [void]$StatementType.Pop()
                        }
                    }
                    #Could be done as assign in operator branch
                    elseif ($Previous.Content -in @("++","--"))
                    {
                        $Script += ";"
                        if ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                        {
                            if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                        }
                    }
                    elseif ($Previous.Type -eq "StatementSeparator")
                    {
                        $Token = $Previous
                    }
                }
                "Operator"
                {
                    if ($Token.Content -eq "[")
                    {
                        $StatementType.Push("Bracket")
                    }
                    elseif ($Token.Content -eq "]")
                    {
                        while($StatementType.Peek() -ne "Bracket")
                        {
                            if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                        }
                        if ($StatementType.Count -gt 0) {[void]$StatementType.Pop()}
                    }
                    elseif ($Token.Content -match "=")
                    {
                        if (-not ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign"))
                        {
                            $StatementType.Push("Assign")
                        }
                    }
                    elseif ($Token.Content -eq "," -and $StatementType.ToArray()[2] -eq "Param")
                    {
                        if ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                        {
                            [void]$StatementType.Pop()
                        }
                    }
                    elseif ($Token.Content -match "-[a-z]+")
                    {
                        if ($Previous.Type -notin @("GroupStart","GroupEnd"))
                        {
                            $Script += ' '
                        }
                        if (-not ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign"))
                        {
                            $StatementType.Push("Assign")
                        }
                    }
                    elseif ($Token.Content -eq "|")
                    {
                        if ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign")
                        {
                            [void]$StatementType.Pop()
                        }
                    }
                    elseif ($Token.Content -match '>&')
                    {
                        $Script += ' '
                    }
                    $Script += $Token.Content
                }
                "Comment"{}
                "Member"
                {
                    $Script += $Token.Content
                    if (-not ($StatementType.Count -gt 0 -and $StatementType.Peek() -eq "Assign"))
                    {
                        $StatementType.Push("Assign")
                    }
                }
                "LineContinuation"{}
                "Type"
                {
                    if ($Previous.Content -in @("Catch","Trap"))
                    {
                        $Script += ' '
                        $Script += $Token.Content
                    }
                    else
                    {
                        $Script += $Token.Content -replace 'System.',''
                    }
                }
                default
                {
                    $Script += $Token.Content
                }
            }
            $Previous = $Token
        }
        if ($Script.Substring(($Script.Length-1)) -eq ";")
        {
            $Script = $Script.Substring(0,($Script.Length-1))
        }
        $Script
    }

    function MinifyParams
    {
        param
        (
            [string] $Script
        )

        $Script -replace "function ([^{]*)\{param\((((?'BR'\()|(?'-BR'\))|[^()]*)+)\)",'function $1($2){'
    }

    if ($ScriptPath)
    {
        $ScriptPath = (ls $ScriptPath).FullName
        $ScriptContent = [IO.File]::ReadAllText($ScriptPath)
    }
    elseif($ScriptContent -is [Array])
    {
        $ScriptContent = $ScriptContent -join "`n"
    }

    $ParseErrors = $null
    $Tokenized = [System.Management.Automation.PSParser]::Tokenize($ScriptContent, [ref]$ParseErrors)
    $Script = Reassemble $Tokenized
    $Script = MinifyParams $Script

    if ($Measure)
    {
        $retval = "" | select Script,Original,Minified,Percent
        $retval.Script = $ScriptPath
        $retval.Original = (cat $ScriptPath | Measure-Object -Character).Characters
        $retval.Minified = $Script.Length
        $retval.Percent = "{0:P0}" -f (1 - ($retval.Minified / $retval.Original)) 
        $retval
    }
    else
    {
        if ($OutPath)
        {
            $Script > $OutPath
        }
        else
        {
            $Script
        }
    }
}