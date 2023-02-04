#!/bin/bash
# By zartek.creole@gmail.com
# https://github.com/ZarTek-Creole

######## CONFIG
API_PASSWORD=password
API_PORT=55477
API_HOST=localhost
API_ARGS='?status=RUNNING'
TIME_MAX_DEFAULT=420
TIME_SLEEP=0.7

FILE_CONFIG=/root/cbftp_control.cfg
FILE_LOG=/root/cbftp_control.log

######## CONFIG END
NUMBER_LIST=$(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs${API_ARGS}" --insecure -s | jq length)
echo "Verification dans '${NUMBER_LIST}' spreadjobs: $API_ARGS."
echo "Temps entre deux requettes: $TIME_SLEEP secondes"
echo "Listes des sections: $(while IFS='=' read -r SECT TIME; do echo $SECT; done < cbftp_control.cfg | xargs echo)"
for RELEASE in $(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs${API_ARGS}" --insecure -s | jq -r '.[]'); do
	sleep $TIME_SLEEP
	data=$(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}" --insecure -s)
	TIME=$(echo "$data" | jq '.time_spent_seconds')
	SECTION=$(echo "$data" | jq -r '.section')
	### Si le fichier config existe; et que la section existe :
	if [[ -f "$FILE_CONFIG" && "$(grep -c -w "$SECTION" "$FILE_CONFIG")" = 1 ]]; then
		### on recuper le temps max, et la section
		TIME_MAX=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f2 | tr -d "\"")
		SECTION_CONFIG=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f1 | tr -d "\"")
		# si le fichier existe pas, ou que la section existe pas:
	else
		#on prend le temps par default
		TIME_MAX=$TIME_MAX_DEFAULT
		SECTION_CONFIG=DEFAULT
	fi
	if (( "$TIME" > "$TIME_MAX" )); then
		STATUS_ABORT=$(curl -u :${API_PASSWORD} -X POST "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}/abort" -d '{ "delete": "NONE"}' --insecure -s -w "%{http_code}")
		MSG="[$(date +"%d-%m-%y à %T")] abort ${RELEASE} | $SECTION ($SECTION_CONFIG) | $(date -d@"${TIME}" -u +%H:%M:%S) (max: $(date -d@${TIME_MAX} -u +%H:%M:%S)) | STATUS HTTP $STATUS_ABORT"
		echo $MSG
		echo $MSG >> $FILE_LOG
	else 
		echo "[$(date +"%d-%m-%y à %T")] OK ${RELEASE} | $SECTION ($SECTION_CONFIG) | $(date -d@"${TIME}" -u +%H:%M:%S) (max: $(date -d@${TIME_MAX} -u +%H:%M:%S))"
	fi
done
echo "Fin"
