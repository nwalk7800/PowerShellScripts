Function GUnzip-File{
    Param
    (
        [string[]]$Path,
        $OutFile
    )

    foreach ($file in $Path)
    {
        $infile = ls $file
        if (-not $OutFile)
        {
            $OutFile = $infile.FullName -replace '\.gz$',''
        }

        $input = New-Object System.IO.FileStream $infile.FullName, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $output = New-Object System.IO.FileStream $OutFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
        $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
        $test = New-Object System.IO.Compression.

        $buffer = New-Object byte[](1024)
        while($true){
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0){break}
                $output.Write($buffer, 0, $read)
            }

        $gzipStream.Close()
        $output.Close()
        $input.Close()
    }
}