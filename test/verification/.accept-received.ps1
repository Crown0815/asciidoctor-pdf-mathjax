#!/usr/bin/env pwsh

# Overwrite all *.verified.pdf files with the corresponding *.received.pdf files
Get-ChildItem -Path $PSScriptRoot -Filter *.received.pdf | ForEach-Object {
    $verified = $_.FullName -replace 'received', 'verified'
    Copy-Item -Path $_.FullName -Destination $verified -Force
}
