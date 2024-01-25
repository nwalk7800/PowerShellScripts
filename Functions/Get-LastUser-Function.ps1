function Get-LastUser
{
    param
    (
        $ComputerName = "."
    )
    
    $retval = @()
    foreach ($Computer in $ComputerName)
    {
        foreach ($User in (gwmi Win32_UserProfile -ComputerName $Computer | sort -Descending LastUseTime))
        {
            if ($User.SID.Length -gt 8)
            {
                $UserName =  (Get-ADUser $User.SID -ErrorAction SilentlyContinue).SamAccountName
                if ($UserName -notmatch "admin\..*")
                {
                    New-Object psobject -Property @{
                        ComputerName = $Computer
                        UserName = $UserName
                        LastLogon = $User.ConvertToDateTime($User.LastUseTime)
                    }

                    $retval += $obj
                    
                    $UserName = ""
                    break
                }
            }
        }

    }
    $retval
}