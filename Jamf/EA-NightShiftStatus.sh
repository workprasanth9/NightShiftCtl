#!/bin/bash
# Jamf Pro extension attribute: reports Night Shift state for the logged in user.
# Result example: <result>on | strength 50 | schedule sunset-to-sunrise</result>

NIGHTSHIFT="/usr/local/bin/nightshift"
CONSOLE_USER=$(/usr/bin/stat -f%Su /dev/console)

if [[ ! -x "$NIGHTSHIFT" ]]; then
  echo "<result>not installed</result>"; exit 0
fi
if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
  echo "<result>no user logged in</result>"; exit 0
fi

USER_ID=$(/usr/bin/id -u "$CONSOLE_USER")
OUTPUT=$(/bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CONSOLE_USER" "$NIGHTSHIFT" status 2>/dev/null)

STATE=$(echo "$OUTPUT" | awk -F': *' '/^Night Shift/ {print $2}')
STRENGTH=$(echo "$OUTPUT" | awk -F': *' '/^Strength/ {print $2}')
SCHEDULE=$(echo "$OUTPUT" | awk -F': *' '/^Schedule/ {print $2}')

echo "<result>${STATE:-unknown} | strength ${STRENGTH:-?} | schedule ${SCHEDULE:-?}</result>"
