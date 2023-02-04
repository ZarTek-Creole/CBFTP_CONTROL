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
readonly FILE_CONFIG=./cbftp_control.cfg
readonly FILE_LOG=./cbftp_control.log

# Get the number of spreadjobs
get_spreadjob_count() {
  curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs${API_ARGS}" --insecure -s | jq length
}

# Get the time max for a given section
get_time_max() {
  local section="$1"
  if [[ -f "$FILE_CONFIG" && "$(grep -c -w "$section" "$FILE_CONFIG")" = 1 ]]; then
    grep -w "$section" "$FILE_CONFIG" | cut -d "=" -f2 | tr -d "\""
  else
    echo "$TIME_MAX_DEFAULT"
  fi
}

# Abort a spreadjob
abort_spreadjob() {
  local release="$1"
  local status_abort=$(curl -u :${API_PASSWORD} -X POST "https://${API_HOST}:${API_PORT}/spreadjobs/${release}/abort" -d '{ "delete": "NONE"}' --insecure -s -w "%{http_code}")
  if [[ "$status_abort" == "200" ]]; then
    local msg="[$(date +"%d-%m-%y à %T")] Aborted ${release} | $(get_spreadjob_section "$release") ($(get_section_config "$release")) | Time spent $(get_spreadjob_time_spent "$release") (max: $(date -d@"$(get_time_max "$(get_spreadjob_section "$release")")" -u +%H:%M:%S)) | HTTP status $status_abort"
    echo "$msg"
    echo "$msg" >> "$FILE_LOG"
  else
    echo "HTTP error $status_abort while aborting ${release}"
  fi
}

# Get the section for a spreadjob
get_spreadjob_section() {
  local release="$1"
  curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs/${release}" --insecure -s | jq -r '.section'
}

# Function to get the configuration for a spreadjob section
get_section_config() {
  local SECTION=$1
  if [[ -f "$FILE_CONFIG" && "$(grep -c -w "$SECTION" "$FILE_CONFIG")" = 1 ]]; then
    TIME_MAX=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f2 | tr -d "\"")
    SECTION_CONFIG=$(grep -w "$SECTION" "$FILE_CONFIG" | cut -d "=" -f1 | tr -d "\"")
  else
    TIME_MAX=$TIME_MAX_DEFAULT
    SECTION_CONFIG=DEFAULT
  fi
}

# Function to get the data for a spreadjob
get_spreadjob_data() {
  local RELEASE=$1
  sleep $TIME_SLEEP
  data=$(curl -u :${API_PASSWORD} "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}" --insecure -s)
  TIME=$(echo "$data" | jq '.time_spent_seconds')
  SECTION=$(echo "$data" | jq -r '.section')
  get_section_config "$SECTION"
}

# Function to abort a spreadjob
abort_spreadjob() {
  local RELEASE=$1
  STATUS_ABORT=$(curl -u :${API_PASSWORD} -X POST "https://${API_HOST}:${API_PORT}/spreadjobs/${RELEASE}/abort" -d '{ "delete": "NONE"}' --insecure -s -w "%{http_code}")
  if [[ "$STATUS_ABORT" == "200" ]]; then
    MSG="[$(date +"%d-%m-%y à %T")] Aborted ${RELEASE} | $SECTION ($SECTION_CONFIG) | Time spent $(date -d@"${TIME}" -u +%H:%M:%S) (max: $(date -d@"${TIME_MAX}" -u +%H:%M:%S)) | HTTP status $STATUS_ABORT"
    echo "$MSG"
    echo "$MSG" >> $FILE_LOG
  else
    echo "HTTP error $STATUS_ABORT while aborting ${RELEASE}"
  fi
}
