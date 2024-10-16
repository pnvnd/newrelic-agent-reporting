#!/usr/bin/env pwsh

# $accountId = "1234567"
$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$apiEndpoint = "https://api.newrelic.com/graphql"

# Initialize variables
$cursor = "cursor:null"
$entities = @()

# Loop until cursor is "None"
while ($cursor -ne "cursor:""""") {

  # Define NerdGraph query
  $QUERY = @{"query" = @"
{
  actor {
    entitySearch(
      query: "domain IN ('APM','INFRA') AND type IN ('APPLICATION','HOST') AND reporting='true'"
      options: {tagFilter: "appid"}
    ) {
      results($cursor) {
        entities {
          guid
          name
          entityType
          type
          domain
          tags {
            key
            values
          }
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
    -Headers @{ "Api-Key" = $apiKey } `
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
| Select-Object @{Name="AccountName"; Expression={$_.account.name}}, @{Name="AccountId"; Expression={$_.account.id}}, domain, type, entityType, name, guid, @{Name="New Relic Link"; Expression={"https://one.newrelic.com/redirect/entity/"+$_.guid}}, @{Name="tags.key"; Expression={$_.tags.key}}, @{Name="tags.values"; Expression={$_.tags.values}}
| ConvertTo-CSV -NoTypeInformation 
| Add-Content -Path "apm_tagged.csv"