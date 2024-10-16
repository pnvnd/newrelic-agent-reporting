#!/usr/bin/env pwsh

$apiKey = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
$apiEndpoint = "https://api.newrelic.com/graphql"

# Initialize variables
$cursor = "cursor:null"
$users = @()

# Loop until cursor is "None"
while ($cursor -ne "cursor:""""") {
# Define NerdGraph query
$QUERY = @{
"query" = @"
{
  actor {
    organization {
      userManagement {
        authenticationDomains {
          authenticationDomains {
            users($cursor) {
              nextCursor
              users {
                id
                name
                email
                lastActive
                timeZone
                type {
                  displayName
                }
                groups {
                  groups {
                    displayName
                  }
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

  # Post request to GraphQL
  $REQUEST = Invoke-WebRequest -Uri $apiEndpoint `
      -Method POST `
      -Headers @{"Api-Key" = $apiKey } `
      -ContentType "application/json" `
      -Body $QUERY

  $RESPONSE = $REQUEST | Select-Object Content -ExpandProperty Content | ConvertFrom-Json

  # Loop through GraphQL query for each cursor
  if ($RESPONSE) {
    $users += $RESPONSE.data.actor.organization.userManagement.authenticationDomains.authenticationDomains.users.users | ForEach-Object {
      if ($_) {
        if ($_.type -and $_.type.displayName) {
          $_.type = $_.type.displayName  # Extract the display name from the nested object
        }
        if ($_.groups -and $_.groups.groups) {
          $groupDisplayNames = $_.groups.groups | ForEach-Object { $_.displayName } # Extract group display names
          $_.groups = $groupDisplayNames -join ', '  # Combine group display names into a comma-separated string
        } else {
          $_ | Add-Member -MemberType NoteProperty -Name groups -Value "N/A" -Force  # Add or update 'groups' property with 'N/A'
        }
        $_  # Return the modified user object
      }
    }
    $nextCursor = $RESPONSE.data.actor.organization.userManagement.authenticationDomains.authenticationDomains.users.nextCursor
    $cursor = "cursor:""$nextCursor"""
  }
  else {
      throw "Query failed to run."
  }
}

$users | ConvertTo-CSV -NoTypeInformation | Add-Content -Path "nr_users.csv"