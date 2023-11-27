# Script version: 2.0 - Synthetics agent list results saved to a file

# Generate a User API Key for a personal account
$API_KEY = 'User API Key'  # Replace with your actual New Relic User API Key

# Master account ID
$MasterAccountId = 'Master Account ID'  # Replace with your actual New Relic Master Account ID

# File path for synthetics results in the same directory as the script
$syntheticsResultFilePath = Join-Path $PSScriptRoot "synthetics_results.txt"

# GraphQL query to fetch unique consuming account IDs
$mainQuery = ConvertTo-Json @{
    "query" = @"
        {
            actor {
                account(id: $MasterAccountId) {
                    subAccounts: nrql(query: "SELECT uniques(consumingAccountId) as 'consumingAccountIds' FROM NrConsumption SINCE 14 DAYS AGO", timeout: 5) {
                        results
                    }
                }
            }
        }
"@
}

# Sending the request for the main query
$mainResponse = Invoke-RestMethod -Uri "https://api.eu.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $mainQuery

# Log the consuming account IDs from the main query
$consumingAccountIdsRaw = $mainResponse.data.actor.account.subAccounts.results[0].consumingAccountIds
# remove trailing .0 from each ID (for some reson the API returns them as floats)
$consumingAccountIds = $consumingAccountIdsRaw | ForEach-Object { [int]$_ }
Write-Output "Consuming Account IDs:"
$consumingAccountIds | ConvertTo-Json | Write-Output

# Loop through each sub-account ID and run the synthetics query
foreach ($SubAccountId in $consumingAccountIds) {
    $subQuery = ConvertTo-Json @{
        "query" = @"
            {
                actor {
                    account(id: $SubAccountId) {
                        synthetics: nrql(query: "SELECT count(*) FROM SyntheticsPrivateMinion WHERE minionIsPrivate FACET minionId, minionBuildVersion, minionContainerSystemEnv, minionLocation, minionOsName, minionOsVersion", timeout: 5) {
                            results
                        }
                    }
                }
            }
"@
    }

    # Sending the synthetics sub-query for each sub-account
    $subResponse = Invoke-RestMethod -Uri "https://api.eu.newrelic.com/graphql" -Method Post -Headers @{ "Api-key" = $API_KEY; "Content-Type" = "application/json"} -Body $subQuery

    # Write the results for each sub-account to the synthetics file
    foreach ($result in $subResponse.data.actor.account.synthetics.results) {
        $facets = $result.facet -join ", "
        $line = "$SubAccountId, $facets"
        Add-Content -Path $syntheticsResultFilePath -Value $line
    }
}
