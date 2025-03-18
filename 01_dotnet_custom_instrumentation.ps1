# Get the log files from C:\ProgramData\New Relic\.NET Agent\Log\
# To use script, either add file or folder path to output a CSV file:
# 01_dotnet_custom_instrumentation.ps1 './NewRelic.Profiler.xxxx.log`
# 01_dotnet_custom_instrumentation.ps1 'C:\ProgramData\New Relic\.NET Agent\Log\`

param (
    [string]$inputPath
)

# Check if the input path exists
if (-Not (Test-Path -Path $inputPath)) {
    Write-Error "The path '$inputPath' does not exist."
    exit 1
}

# Initialize an array to hold all lines
$allLines = @()

# Determine output file name based on input type
if (Test-Path -Path $inputPath -PathType Leaf) {
    # Single file (Leaf indicates it's a file)
    $files = @(Get-Item -Path $inputPath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
} else {
    # All files in the directory
    $files = Get-ChildItem -Path $inputPath -File -Filter NewRelic.Profiler.*
    $baseName = [System.IO.Path]::GetFileName($inputPath.TrimEnd('\', '/'))
}

foreach ($file in $files) {
    # Step 1: Filter lines with "No instrumentation point for"
    $lines = Get-Content -Path $file.FullName | Where-Object { $_ -match 'No instrumentation point for' }

    # Step 2: Remove lines that match specific patterns
    $step2Regex = '^(.*(EE Shared Assembly|Microsoft\.GeneratedCode|ctor|log4net|NewRelic|Win32|System\.Configuration|System\.Collections|System\.Core|System\.ComponentModel|System\.Data|System\.Diagnostics|System\.DomainNameHelper|System\.Management|System\.Security|System\.Text|System\.Uri|System\.Xml).*)$'
    $lines = $lines | Where-Object { $_ -notmatch $step2Regex }

    # Step 3: Remove everything up to the second open-bracket [
    $step3Regex = '^.*?\[.*?\['
    $lines = $lines -replace $step3Regex, ''

    # Step 4: Remove everything inside the parentheses
    $step4Regex = '\(([^\)]+)\)'
    $lines = $lines -replace $step4Regex, ''

    # Step 5: Remove lines ending with ()
    $step5Regex = '.*\(\)$'
    $lines = $lines | Where-Object { $_ -notmatch $step5Regex }

    # Step 6: Replace close-bracket ] with a comma-space
    $step6Regex = '\]'
    $lines = $lines -replace $step6Regex, ', '

    # Step 7: Replace last occurring dot . with a comma-space
    $step7Regex = '\.(?!.*\.)'
    $lines = $lines -replace $step7Regex, ', '

    # Step 8: Remove empty lines
    $lines = $lines | Where-Object { $_ -ne "" }

    # Append results to the master collection
    $allLines += $lines
}

# Step 9: Sorting by ascending order
$allLines = $allLines | Sort-Object

# Step 10: Remove duplicates
$allLines = $allLines | Sort-Object -Unique

# Insert header
$header = "assemblyName, className, methodName"
$allLines = $header + "`n" + ($alllines -join "`n")

# Construct output file path
$outputFile = [System.IO.Path]::Combine((Split-Path -Path $inputPath -Parent), "$baseName.csv")

# Step 11: Save as .csv file
$allLines | Set-Content -Path $outputFile -Encoding UTF8

Write-Output "Processed file saved as '$outputFile'"