## New Relic Agent Reporting Scripts

This repository contains a collection of PowerShell scripts designed to interact with the New Relic API. Each script fetches data related to different New Relic agents (APM, Mobile, and Synthetics) and saves the results to respective files.

### Scripts Overview

**APM and Infra Agent List (Script version: 1.5):**
- Fetches a list of sub-account IDs from New Relic's NrDailyUsage.
For each sub-account, it queries APM and Infrastructure agent data.
Results are saved in apm_results.txt and infra_results.txt.

**Mobile Agent List (Script version: 1.9):**
- Retrieves unique consuming account IDs from NrConsumption.
For each account, runs a query related to Mobile agents.
Results are formatted as a comma-separated list and saved in mobile_results.txt.

**Synthetics Agent List (Script version: 2.0):**
- Similar to the Mobile Agent script, but focused on Synthetics agents.
Fetches Synthetics agent data for each consuming account ID.
Outputs are stored in synthetics_results.txt.

### General Functionality

All scripts follow a similar pattern:
- They start by making a GraphQL query to New Relic to fetch relevant account IDs. (via https://api.newrelic.com/graphql)
- For each account ID, a detailed query is run to fetch specific agent data.
  - such as (sub) account name, app name, agent name, agent version etc
- The results are then written to text files, with each line representing data from one account.

### Requirements
- PowerShell
- Access to New Relic API (API Key required)


### Usage

- Replace `$MasterAccountId` with your actual New Relic Master Account ID.
- Replace `$API_KEY` with your actual New Relic User API Key.
- Run the script in a PowerShell environment.
  - for Windows environment rename the script to `.ps1`
- Check the output files in the same directory as the script for results.

### Notes
- Ensure you have the necessary permissions to access the New Relic data.
- The scripts are tailored for specific New Relic queries but can be modified for different data retrieval needs.
