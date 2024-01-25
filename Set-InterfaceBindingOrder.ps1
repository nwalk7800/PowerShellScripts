Function FixOrder
{
    param
    (
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix
    )

    $NewOrder = @()
    $Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Linkage'

    #get values in registry
    $OldOrder = (Get-ItemProperty $Key $Value).$Value 

    #$NewPubSettingID= "$Prefix$PubSettingID$Suffix"
    $NewPrivateSettingID= "$Prefix$PrivateSettingID$Suffix"
    Write-Host "Current: " $OldOrder[0]

    #Order
    #if ($OldOrder -contains $NewPubSettingID) {$NewOrder += $NewPubSettingID}
    if ($OldOrder[0] -ne $NewPrivateSettingID)
    {
        Write-Host "Old: " + $OldOrder[0]
        Write-Host "New: " + $NewPrivateSettingID

        $NewOrder += $NewPrivateSettingID
        $NewOrder += $OldOrder
        $NewOrder = $NewOrder | select -Unique

        Write-Host "Old Order"
        $OldOrder | %{Write-Host $_}
        Write-Host "New Order"
        $NewOrder | %{Write-host $_}
        Write-Host ""

        #Set-ItemProperty -path $Key -Name $Value -Value $NewOrder
    }
    else
    {
        Write-Host "No change"
    }
}

Function FixInterfaceBindingOrder
{
    #-------------------------Public Setting ID------------------------------------------------#

    $PublicSettingID = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPenabled = $true" | where {$_.IpAddress -like '10.*'} | select -ExpandProperty Settingid
    Write-host "VPN: $PublicSettingID"

    #-------------------------Private Setting ID------------------------------------------------#

    $PrivateSettingID = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPenabled = $true" | where {$_.IpAddress -like '192.*'}|select -ExpandProperty Settingid
    Write-host "Private: $PrivateSettingID"

    FixOrder -Value 'Bind' -Prefix '\Device\'
    FixOrder -Value 'Export' -Prefix '\Device\Tcpip_'
    FixOrder -Value 'Route' -Prefix '"' -Suffix '"'
}

FixInterfaceBindingOrder