#!/usr/bin/env pwsh

$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$apiEndpoint = "https://api.newrelic.com/graphql"

# Initialize variables
$infrastructureIntegrationType = "AWS_RDS_DB_INSTANCE" # Enter an integration to search for
$cursor = "cursor:null"
$entities = @()

# Loop until cursor is "None"
while ($cursor -ne "cursor:""""") {

  # Define NerdGraph query
  $QUERY = @{"query" = @"
  {
    actor {
      entitySearch(
        queryBuilder: {domain: INFRA, infrastructureIntegrationType: $infrastructureIntegrationType}
      ) {
        results($cursor) {
          entities {
            name
            type
            reporting
            account {
              name
              id
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

# Extract "name" and "id" from the entities
$entities 
| Select-Object @{Name="AccountName"; Expression={$_.account.name}}, @{Name="AccountId"; Expression={$_.account.id}}, name, type, reporting 
| ConvertTo-CSV -NoTypeInformation 
| Add-Content -Path "infra_rds.csv"