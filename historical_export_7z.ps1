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

$ProgressPreference = "SilentlyContinue"
$7zipPath = "C:\Program Files\7-Zip\7z.exe"

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
    -Method POST `
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
  $tempFile = Join-Path (Get-Location).path 'temp.json.gz'
  Invoke-WebRequest -Uri $link `
    -Method GET `
    -OutFile $tempFile
  
  # Define the output path for the decompressed JSON file
  $decompressedFile = Join-Path (Get-Location).path 'temp.json'
  
  # Use 7-Zip to decompress the .gz file
  & $7zipPath x $tempFile -so > $decompressedFile

  # Check if the decompressed file exists
  if (-Not (Test-Path -Path $decompressedFile)) {
      Write-Output "Error: Decompressed file not found at path '$decompressedFile'."
      continue
  }

  # Read the decompressed JSON file
  $jsonString = Get-Content -Path $decompressedFile -Raw
  
  # Parse JSON and convert to CSV format
  $jsonData = $jsonString | ConvertFrom-Json
  $attributes = $jsonData | ForEach-Object { $_.attributes }
  $csv = $attributes | ConvertTo-Csv -NoTypeInformation
  
  # Clean up
  Remove-Item $tempFile
  Remove-Item $decompressedFile
  
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
$filePath = Get-ChildItem $fileName | Select-Object FullName -ExpandProperty FullName
Write-Output "`nCombined CSV created successfully:`n$filePath"
