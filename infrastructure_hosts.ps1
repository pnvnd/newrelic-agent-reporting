#!/usr/bin/env pwsh

$accountId = "1234567"
$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$apiEndpoint = "https://api.newrelic.com/graphql"

# Initialize variables
$nameLike = "" # Enter a host name to search for
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
      entitySearch(queryBuilder: {type: HOST, domain: INFRA, name: "$nameLike"}) {
        results($cursor) {
          entities {
            ... on InfrastructureHostEntityOutline {
              guid
              name
              accountId
              domain
              entityType
              reporting
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
$entities | Where-Object { $_.monitorType -like "*" } | ConvertTo-CSV -NoTypeInformation | Add-Content -Path "infrastructure_host_results.csv"