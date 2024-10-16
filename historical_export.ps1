<#
This is a slow process. Only use this if you are expecting more than 5000 records. Things to note:
 - Query window has to be "UNTIL 12 HOURS AGO" or greater
 - Can't have functions or variables (e.g., aparse)
 - No guarantee on expected completion
 - Results will be provided in an undefined number of download links
 - No Timeslice metrics (Dimensional metrics are okay)
 - 200,000,000 Event limit

 https://docs.newrelic.com/docs/apis/nerdgraph/examples/nerdgraph-historical-data-export/
#>


$apiEndpoint = "https://api.newrelic.com/graphql"
$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$accountId = "#######"

$nrql = @"
SELECT message
FROM Log
WHERE message LIKE '%INFO%'
SINCE YESTERDAY UNTIL TODAY
"@

# Step 1: Create historical data export
$MUTATION = @{"query" = @"
mutation {
  historicalDataExportCreateExport(
    accountId: $accountId,
    nrql: """$nrql"""
  ) {
    id
  }
}
"@
} | ConvertTo-Json

$createExportRequest = Invoke-WebRequest -Uri $apiEndpoint `
  -Method POST `
  -Headers @{ "Api-Key" = $apiKey } `
  -ContentType "application/json" `
  -Body $MUTATION

$createExportResponse = $createExportRequest | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

if ($createExportResponse.errors) {
    Write-Output "Error: $($createExportResponse.errors[0].message)"
    exit
}

$exportId = $createExportResponse.data.historicalDataExportCreateExport.id
Write-Output "Export ID is: $exportId`n"

# Step 2: Check progress until 100%
$percentComplete = 0

while ($percentComplete -lt 100) {
$QUERY = @{"query" = @"
{
  actor {
    account(id: $accountId) {
      historicalDataExport {
        export(id: "$exportId") {
          results
          id
          nrql
          percentComplete
          status
        }
      }
    }
  }
}
"@
    } | ConvertTo-Json

$REQUEST = Invoke-WebRequest -Uri $apiEndpoint `
  -Method Post `
  -Headers @{ "Api-Key" = $apiKey } `
  -ContentType "application/json" `
  -Body $QUERY

$RESPONSE = $REQUEST | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

$percentComplete = $RESPONSE.data.actor.account.historicalDataExport.export.percentComplete

if ($percentComplete -lt 100) {
    Write-Output "Progress: $percentComplete%"
    Start-Sleep -Seconds 60
} else {
    Write-Output "Progress: $percentComplete%"
}
}

# Step 3: Store the results URLs
$downloadLinks = $RESPONSE.data.actor.account.historicalDataExport.export.results
Write-Output $downloadLinks

# Step 4: Stream each file, uncompress, and combine into a single CSV
$combinedCsv = @()
foreach ($link in $downloadLinks) {
    # Download the .gz file
    $gzData = Invoke-RestMethod -Uri $link -Method Get -OutFile 'temp.json.gz'

    # Create a memory stream to hold the decompressed data
    $memoryStream = New-Object IO.MemoryStream

    # Open the downloaded .gz file
    $fileStream = [System.IO.File]::OpenRead('temp.json.gz')
    $gzipStream = New-Object IO.Compression.GzipStream($fileStream, [System.IO.Compression.CompressionMode]::Decompress)

    # Decompress the file
    $buffer = New-Object byte[] 4096
    while (($read = $gzipStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $memoryStream.Write($buffer, 0, $read)
    }

    # Close streams
    $gzipStream.Close()
    $fileStream.Close()

    # Convert the memory stream to a string
    $memoryStream.Position = 0
    $streamReader = New-Object IO.StreamReader($memoryStream)
    $jsonString = $streamReader.ReadToEnd()

    # Parse JSON and convert to CSV format
    $jsonData = $jsonString | ConvertFrom-Json
    $attributes = $jsonData | ForEach-Object { $_.attributes }
    $csv = $attributes | ConvertTo-Csv -NoTypeInformation

    # Clean up
    $memoryStream.Close()
    $streamReader.Close()
    Remove-Item 'temp.json.gz'

    # Combine the CSV data, skipping the header if already added
    if (-not $headerAdded) {
        $combinedCsv += $csv
        $headerAdded = $true
    } else {
        $combinedCsv += $csv | Select-Object -Skip 1
    }
}

# Step 5: Write the combined CSV to a file
$fileName = "historicalDataExport_${exportId}.csv"
$combinedCsv | Out-File -FilePath $fileName -Encoding utf8
$filePath = Get-ChildItem $fileName | Select FullName -ExpandProperty FullName
Write-Output "`nCombined CSV created successfully:`n$filePath"
