# Script version: 1.9 - mobile agent list results saved to a file

# Generate a User API Key for a personal account
$API_KEY = $Env:NEW_RELIC_USER_KEY  # Replace with your actual New Relic User API Key

# Master account ID
$MasterAccountId = $Env:NEW_RELIC_ACCOUNT_ID  # Replace with your actual New Relic Master Account ID

# File path for mobile results in the same directory as the script
$mobileResultFilePath = Join-Path (Get-Location).path "mobile_results.csv"

# GraphQL query to fetch unique consuming account IDs
$mainQuery = ConvertTo-Json @{
    "query" = @"
        {
            actor {
                account(id: $MasterAccountId) {
                    subAccounts: nrql(query: "SELECT uniques(consumingAccountId) as 'consumingAccountIds' FROM NrConsumption SINCE 14 DAYS AGO", timeout: 90) {
                        results
                    }
                }
            }
        }
"@
}

# Sending the request for the main query
$mainResponse = Invoke-RestMethod -Uri "https://api.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $mainQuery

# Log the consuming account IDs from the main query
$consumingAccountIdsRaw = $mainResponse.data.actor.account.subAccounts.results[0].consumingAccountIds
# remove trailing .0 from each ID (for some reson the API returns them as floats)
$consumingAccountIds = $consumingAccountIdsRaw | ForEach-Object { [int]$_ }
Write-Output "Consuming Account IDs:"
$consumingAccountIds | ConvertTo-Json | Write-Output

# Loop through each sub-account ID and run the sub-query
foreach ($SubAccountId in $consumingAccountIds) {
    $subQuery = ConvertTo-Json @{
        "query" = @"
            {
                actor {
                    account(id: $SubAccountId) {
                        mobile: nrql(query: "FROM Mobile SELECT count(*) FACET appName, appVersion, newRelicAgent, newRelicVersion SINCE 2 WEEKS AGO LIMIT MAX", timeout: 90) {
                            results
                        }
                    }
                }
            }
"@
    }

    # Sending the sub-query for each sub-account
    $subResponse = Invoke-RestMethod -Uri "https://api.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $subQuery

    # Write the results for each sub-account to file, formatted as a comma-separated list
    foreach ($result in $subResponse.data.actor.account.mobile.results) {
        $facets = $result.facet -join ", "
        $line = "$SubAccountId, $facets"
        Add-Content -Path $mobileResultFilePath -Value $line
    }
}
