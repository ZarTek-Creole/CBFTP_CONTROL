#!/bin/bash
# By zartek.creole@gmail.com
# https://github.com/ZarTek-Creole

# Constants
readonly API_PASSWORD=TEST
readonly API_PORT=55477
readonly API_HOST=localhost
readonly API_ARGS='?status=RUNNING'
readonly TIME_MAX_DEFAULT=420
readonly TIME_SLEEP=0.7
readonly FILE_CONFIG=/root/cbftp_control.cfg
readonly FILE_LOG=/root/cbftp_control.log

# Get the number of spreadjobs
NUMBER_LIST=$(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs${API_ARGS}" --insecure -s | jq length)
echo "Verification dans '${NUMBER_LIST}' spreadjobs: $API_ARGS."
echo "Temps entre deux requettes: $TIME_SLEEP secondes"
echo "Listes des sections: $(while IFS='=' read -r SECT TIME; do echo "$SECT"; done < $FILE_CONFIG | xargs echo)"

# Loop through each spreadjob
for RELEASE in $(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs${API_ARGS}" --insecure -s | jq -r '.[]'); do
  sleep $TIME_SLEEP
  data=$(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}" --insecure -s)
  TIME=$(echo "$data" | jq '.time_spent_seconds')
  SECTION=$(echo "$data" | jq -r '.section')
  
  # Check if config file exists and if the section exists
  if [[ -f "$FILE_CONFIG" && "$(grep -c -w "$SECTION" "$FILE_CONFIG")" = 1 ]]; then
    TIME_MAX=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f2 | tr -d "\"")
    SECTION_CONFIG=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f1 | tr -d "\"")
  else
    TIME_MAX=$TIME_MAX_DEFAULT
    SECTION_CONFIG=DEFAULT
  fi
  
  # Check if the time spent is greater than the maximum allowed
	if (( "$TIME" > "$TIME_MAX" )); then
		STATUS_ABORT=$(curl -u :${API_PASSWORD} -X POST "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}/abort" -d '{ "delete": "NONE"}' --insecure -s -w "%{http_code}")
		if [[ "$STATUS_ABORT" == "200" ]]; then
			MSG="[$(date +"%d-%m-%y à %T")] Aborted ${RELEASE} | $SECTION ($SECTION_CONFIG) | Time spent $(date -d@"${TIME}" -u +%H:%M:%S) (max: $(date -d@"${TIME_MAX}" -u +%H:%M:%S)) | HTTP status $STATUS_ABORT"
			echo "$MSG"
			echo "$MSG" >> $FILE_LOG
		else
			echo "HTTP error $STATUS_ABORT while aborting ${RELEASE}"
		fi
	else
		echo "[$(date +"%d-%m-%y à %T")] OK ${RELEASE} | $SECTION ($SECTION_CONFIG) | Time spent $(date -d@"${TIME}" -u +%H:%M:%S) (max: $(date -d@"${TIME_MAX}" -u +%H:%M:%S))"
	fi
done