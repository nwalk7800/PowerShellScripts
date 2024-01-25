param (
    [string[]]$VMName = @('Media', 'Plex')
)

function Optimize-VMDisk {
    param (
        [string[]]$VMName = @('Media', 'Plex')
    )

    foreach ($VM in $VMName) {
        Stop-VM -Name $VM
        $VHDPath = (Get-VHD -VMId (Get-VM $VM).VMId).Path

        Mount-VHD $VHDPath -ReadOnly
        Optimize-VHD $VHDPath -Mode Full
        Dismount-VHD $VHDPath

        Start-VM -Name $VM
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    Optimize-VMDisk -VMName $VMName
}