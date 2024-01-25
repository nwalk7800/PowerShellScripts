Function Export-Registry {

    [cmdletBinding()]

    Param(
        [Parameter(Position=0,Mandatory=$True,
        HelpMessage="Enter a registry path using the PSDrive format.",
        ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [ValidateScript({(Test-Path $_) -AND ((Get-Item $_).PSProvider.Name -match "Registry")})]
        [Alias("PSPath")]
        [string[]]$Path,

        [Parameter()]
        [ValidateSet("csv","xml")]
        [string]$ExportType,

        [Parameter()]
        [string]$ExportPath,

        [switch]$NoBinary

    )

    Begin {
        Write-Verbose -Message "$(Get-Date) Starting $($myinvocation.mycommand)"
        #initialize an array to hold the results
        $data=@()
    } #close Begin

    Process {
        #go through each pipelined path
        Foreach ($item in $path) {
            Write-Verbose "Getting $item"
            $regItem=Get-Item -Path $item
            #get property names
            $properties= $RegItem.Property
            Write-Verbose "Retrieved $(($properties | measure-object).count) properties"
            if (-not ($properties)) {
                #no item properties were found so create a default entry
                $value=$Null
                $PropertyItem="(Default)"
                $RegType="String"

                #create a custom object for each entry and add it the temporary array
                $data+=New-Object -TypeName PSObject -Property @{
                    "Path"=$item
                    "Name"=$propertyItem
                    "Value"=$value
                    "Type"=$regType
                    "Computername"=$env:computername
                }
            }

            else {
                #enumrate each property getting itsname,value and type
                foreach ($property in $properties) {
                    Write-Verbose "Exporting $property"
                    $value=$regItem.GetValue($property,$null,"DoNotExpandEnvironmentNames")
                    #get the registry value type
                    $regType=$regItem.GetValueKind($property)
                    $PropertyItem=$property

                    #create a custom object for each entry and add it the temporary array
                    $data+=New-Object -TypeName PSObject -Property @{
                        "Path"=$item
                        "Name"=$propertyItem
                        "Value"=$value
                        "Type"=$regType
                        "Computername"=$env:computername
                    }
                } #foreach
            } #else
        }#close Foreach
    } #close process

    End {
        #make sure we got something back
        if ($data) {
            #filter out binary if specified
            if ($NoBinary) {
                Write-Verbose "Removing binary values"
                $data=$data | Where {$_.Type -ne "Binary"}
            }

            #export to a file both a type and path were specified
            if ($ExportType -AND $ExportPath) {
                Write-Verbose "Exporting $ExportType data to $ExportPath"
                Switch ($exportType) {
                    "csv" { $data | Export-CSV -Path $ExportPath -noTypeInformation }
                    "xml" { $data | Export-CLIXML -Path $ExportPath }
                } #switch
            } #if $exportType
            elseif ( ($ExportType -AND (-not $ExportPath)) -OR ($ExportPath -AND (-not $ExportType)) ) {
                Write-Warning "You forgot to specify both an export type and file."
            }
            else {
                #write data to the pipeline
                $data
            }
        } #if $#data
        else {
            Write-Verbose "No data found"
            Write "No data found"
        }
        #exit the function
        Write-Verbose -Message "$(Get-Date) Ending $($myinvocation.mycommand)"
    } #close End

} #end Function