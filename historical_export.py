import requests
import time
import gzip
import json
import csv
import os

api_endpoint = "https://api.newrelic.com/graphql"
api_key = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXXXX"
account_id = "#######"

nrql = """
SELECT message
FROM Log
WHERE message LIKE '%INFO%'
SINCE YESTERDAY UNTIL TODAY
"""

# Step 1: Create historical data export
mutation = """
mutation {
  historicalDataExportCreateExport(
    accountId: %s,
    nrql: \"\"\"%s\"\"\"
  ) {
    id
  }
}
""" % (account_id, nrql)

headers = {
    'Api-Key': api_key,
    'Content-Type': 'application/json'
}

response = requests.post(api_endpoint, json={'query': mutation}, headers=headers)
create_export_response = response.json()

if 'errors' in create_export_response:
    print(f"Error: {create_export_response['errors'][0]['message']}")
    exit()

export_id = create_export_response['data']['historicalDataExportCreateExport']['id']
print(f"Export ID is: {export_id}\n")

# Step 2: Check progress until 100%
percent_complete = 0
while percent_complete < 100:
    query = """
    {
      actor {
        account(id: %s) {
          historicalDataExport {
            export(id: "%s") {
              results
              id
              nrql
              percentComplete
              status
            }
          }
        }
      }
    }
    """ % (account_id, export_id)

    response = requests.post(api_endpoint, json={'query': query}, headers=headers)
    progress_response = response.json()
    percent_complete = progress_response['data']['actor']['account']['historicalDataExport']['export']['percentComplete']

    if percent_complete < 100:
        print(f"Progress: {percent_complete}%")
        time.sleep(60)
    else:
        print(f"Progress: {percent_complete}%\n")

# Step 3: Store the results URLs
download_links = progress_response['data']['actor']['account']['historicalDataExport']['export']['results']
for link in download_links:
    print(link)

# Step 4: Stream each file, uncompress, and combine into a single CSV
combined_csv = []
header_added = False

for link in download_links:
    temp_file = 'temp.json.gz'

    # Download the .gz file
    with requests.get(link, stream=True) as r:
        r.raise_for_status()
        with open(temp_file, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

    # Decompress the file
    with gzip.open(temp_file, 'rt', encoding='utf-8') as gz:
        json_data = json.load(gz)
        attributes = [record['attributes'] for record in json_data]

        # Convert to CSV format
        csv_output = []
        if not header_added:
            csv_output.append(attributes[0].keys())
            header_added = True
        for attr in attributes:
            csv_output.append(attr.values())
        
        combined_csv.extend(csv_output)

    os.remove(temp_file)

# Step 5: Write the combined CSV to a file
csv_file_name = f"historicalDataExport_{export_id}.csv"
with open(csv_file_name, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerows(combined_csv)

print(f"\nCombined CSV created successfully:\n{os.path.abspath(csv_file_name)}")
