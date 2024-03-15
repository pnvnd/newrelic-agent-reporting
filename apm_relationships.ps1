#!/usr/bin/env pwsh

$accountId = "1"
$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$apiEndpoint = "https://api.newrelic.com/graphql"

# Manually input entities
# $entities = '[
#     {"guid": "MXyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy", "name": "java-app_dev"},
#     {"guid": "MXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "name": "java-app_prod"}
# ]' | ConvertFrom-Json

# Initialize variables
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
    entitySearch(query: "domain='APM' AND reporting='true'") {
      results($cursor) {
        entities {
          guid
          name
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

# Initialize results to be written to CSV
$results = @()

foreach ($entity in $entities) {
    $guid = $entity.guid
$DATA = @{"query" = @"
{
    actor {
      entity(guid: "$guid") {
        ... on ApmApplicationEntity {
          guid
          name
          relatedEntities {
            results {
              ... on EntityRelationshipDetectedEdge {
                type
                target {
                  entity {
                    name
                    type
                  }
                }
                source {
                  entity {
                    name
                    type
                  }
                }
              }
            }
          }
        }
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
    -Body $DATA

$REP = $REQ | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

# Loop through GraphQL query for each cursor
if ($REQ) {
    $instances = $REP.data.actor.entity.relatedEntities.results
    foreach ($instance in $instances) {
        $results += [PSCustomObject]@{
            app = $REP.data.actor.entity.name
            source_name = $instance.source.entity.name
            source_type = $instance.source.entity.type
            relationship = $instance.type
            target_name = $instance.target.entity.name
            target_type = $instance.target.entity.type
        }
    }
}
else {
    throw "Query failed to run."
}
}

# Export results to CSV
$results | ConvertTo-CSV -NoTypeInformation | Add-Content -Path "apm_relationships.csv"