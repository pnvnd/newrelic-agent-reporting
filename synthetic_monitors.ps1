#!/usr/bin/env pwsh

# ENTRY POINT MAIN()
Param(
    [Parameter(Mandatory=$True)]
    [String] $accountId,
    [Parameter(Mandatory=$True)]
    [String] $apiKey,
    [Parameter(Mandatory=$True)]
    [String] $apiEndpoint
)

# $accountId = "1234567"
# $apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
# $apiEndpoint = "https://api.newrelic.com/graphql"

# Define New Relic API endpoint and headers
# if region = US then $apiEndpoint = "https://api.newrelic.com/graphql"
# if region = EU then $apiEndpoint = "https://api.eu.newrelic.com/graphql"

# Initialize variables
$nameLike = "" # Enter a synthetic monitor name to search for
$cursor = "cursor:null"
$entities = @()

# Loop until cursor is "None"
while ($cursor -ne "cursor:""""") {

  # Define NerdGraph query
  $QUERY = @{"query" = @"
{
  actor {
    account(id: $accountId) {
      id
    }
    entitySearch(queryBuilder: {type: MONITOR, domain: SYNTH, name: "$nameLike"}) {
      results($cursor) {
        entities {
          ... on SyntheticMonitorEntityOutline {
            name
            monitorType
            guid
            entityType
            monitoredUrl
            period
            permalink
            monitorId
            accountId
          }
        }
        nextCursor
      }
    }
  }
}
"@
  } | ConvertTo-Json

  # Post request to GraphQL
  $REQUEST = Invoke-WebRequest -Uri $apiEndpoint `
    -Method POST `
    -Headers @{"Api-Key" = $apiKey } `
    -ContentType "application/json" `
    -Body $QUERY

  $RESPONSE = $REQUEST | Select-Object Content -ExpandProperty Content | ConvertFrom-Json
  
  # Loop through GraphQL query for each cursor
  if ($RESPONSE) {
    $entities += $RESPONSE.data.actor.entitySearch.results.entities
    $nextCursor = $RESPONSE.data.actor.entitySearch.results.nextCursor
    $cursor = "cursor:""$nextCursor"""
  }
  else {
    throw "Query failed to run."
  }
}

# Export results to CSV file
$entities | Where-Object { $_.monitorType -like "*" } | ConvertTo-CSV -NoTypeInformation | Add-Content -Path "synthetic_monitor_results.csv"

# Change monitorType -like "*" to either "SIMPLE", "BROWSER", "CERT_CHECK", "SCRIPT_BROWSER", "SCRIPT_API" to filter
$entityGuid = $entities | Where-Object { $_.monitorType -like "SIMPLE" } | Select-Object guid -ExpandProperty guid

# Set Private Location GUID to be updated
$privateLocationGuid = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# List to store failed guids
$failedGuids = @()

foreach ($guid in $entityGuid) {
  $retryCount = 0

  while ($true) {
    # This is for SIMPLE (ping) monitors only, change monitor type as needed. 
    # Note: SIMPLE does not use {guid: "$privateLocationGuid"} like the other monitor types
    $UPDATE = @{"query" = @"
mutation {
  syntheticsUpdateSimpleMonitor(guid: "$guid", monitor: {locations: {private: "$privateLocationGuid"}}) {
    monitor {
      name
      status
      locations {
        private
      }
    }
    errors {
      description
    }
  }
}
"@
    } | ConvertTo-Json

    # Post request to GraphQL, payload is JSON
    $REQ = Invoke-WebRequest -Uri $apiEndpoint `
      -Method POST `
      -Headers @{"Api-Key" = $apiKey } `
      -ContentType "application/json" `
      -Body $UPDATE

    if ($REQ.StatusCode -eq 200) {
      $REP = $REQ | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

      if ($REP) {
        $ERRORS = $REP.errors

        if ($REP.data.syntheticsUpdateSimpleMonitor.errors) {
          Write-Error "GraphQL Errors for $guid" 
          Write-Error $($REP.data.syntheticsUpdateSimpleMonitor.errors)
          Write-Output "Waiting for 60 seconds before retrying..."
          Start-Sleep -Seconds 60
          $retryCount++

          if ($retryCount -ge 3) {
            Write-Output "Max retry attempts reached for guid: $guid."
            $failedGuids += $guid
            break
          }

          continue  # Retry the current iteration
        }

        if (-not $ERRORS) {
          Write-Output $REQ | Select-Object Content -ExpandProperty Content
          break
        }

        else {
          Write-Output "Error for guid $guid." 
          Write-Output "Error Message: $($REP.errors.message)"
          Write-Output "Waiting for 60 seconds before retrying..."
          Start-Sleep -Seconds 60
          $retryCount++

          if ($retryCount -ge 3) {
            Write-Output "Max retry attempts reached for guid: $guid."
            $failedGuids += $guid
            break
          }

          continue  # Retry the current iteration
        }
      }
      else {
        Write-Output "Unexpected response structure for guid: $guid. Retrying..."
        Start-Sleep -Seconds 60
        $retryCount++

        if ($retryCount -ge 3) {
          Write-Output "Max retry attempts reached for guid: $guid."
          $failedGuids += $guid
          break
        }

        continue  # Retry the current iteration
      }
    }
    else {
      Write-Output "Query failed to run with a $($REQ.StatusCode)."
      Write-Output "Response: $REP)"
      throw "Query failed to run with a $($REQ.StatusCode)."
    }
  }
}

# Output failed guids
if ($failedGuids.Count -gt 0) {
  Write-Output "Failed to update the following guids: $($failedGuids -join ', ')"
}

Write-Output "Completed running script."