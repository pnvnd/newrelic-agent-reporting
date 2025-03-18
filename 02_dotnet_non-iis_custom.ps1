# Get the CSV output from # 01_dotnet_custom_instrumentation.ps1 or
# create a CSV file with the headers: assemblyName, className, methodName
# ./dotnet_non-iis_custom.ps1 './NewRelic.Profiler.xxxx.csv'
# ./dotnet_non-iis_custom.ps1 'C:\ProgramData\New Relic\.NET Agent\Log\`
# This will generate an XML that can be placed in C:\ProgramData\New Relic\.NET Agent\Extensions for custom instrumentation.
# Note: The resulting XML file is specific for non-IIS .NET applications

param (
    [string]$csvFilePath
)

# Check if the CSV file exists
if (-Not (Test-Path -Path $csvFilePath)) {
    Write-Error "The file '$csvFilePath' does not exist."
    exit 1
}

# Read the CSV file contents
$csvData = Import-Csv -Path $csvFilePath

# Generate the XML content
$xmlContent = @("<?xml version=""1.0"" encoding=""utf-8""?>")
$xmlContent += "<extension xmlns=""urn:newrelic-extension"">"
$xmlContent += "  <instrumentation>"

# Loop through each row in the CSV file to add tracerFactory blocks
foreach ($row in $csvData) {
    $assemblyName = $row.assemblyName
    $className = $row.className
    $methodName = $row.methodName
    
    $xmlContent += "    <!-- Define the method which triggers the creation of a transaction. -->"
    $xmlContent += "    <tracerFactory name=""NewRelic.Agent.Core.Tracer.Factories.BackgroundThreadTracerFactory"" metricName=""Custom/$methodName"">"
    $xmlContent += "      <match assemblyName=""$assemblyName"" className=""$className"">"
    $xmlContent += "        <exactMethodMatcher methodName=""$methodName"" />"
    $xmlContent += "      </match>"
    $xmlContent += "    </tracerFactory>"
}

$xmlContent += "  </instrumentation>"
$xmlContent += "</extension>"

# Determine output XML file path
$outputFilePath = [System.IO.Path]::ChangeExtension($csvFilePath, "xml")

# Save the XML content to a file
$xmlContent | Out-File -FilePath $outputFilePath -Encoding utf8

Write-Output "XML file saved as '$outputFilePath'"