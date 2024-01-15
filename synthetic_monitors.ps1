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
  -Headers @{"Api-Key"=$apiKey} `
  -ContentType "application/json" `
  -Body $QUERY

  $RESPONSE = $REQUEST | Select-Object Content -ExpandProperty Content | ConvertFrom-Json
  
  # Loop through GraphQL query for each cursor
  if ($RESPONSE) {
      $entities += $RESPONSE.data.actor.entitySearch.results.entities
      $nextCursor = $RESPONSE.data.actor.entitySearch.results.nextCursor
      $cursor = "cursor:""$nextCursor"""
  } else {
      throw "Query failed to run."
  }

}

# Change monitorType -like "*" to either "SIMPLE", "BROWSER", "CERT_CHECK", "SCRIPT_BROWSER", "SCRIPT_API" to filter
$entities | Where-Object { $_.monitorType -like "*" } | ConvertTo-CSV -NoTypeInformation | Add-Content -Path "synthetic_monitor_results.csv"
