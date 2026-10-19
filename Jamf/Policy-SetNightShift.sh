#!/bin/bash
# Jamf Pro policy script: applies a Night Shift baseline for the logged in user.
# Parameter 4: schedule  ("sunset", "off", or "HH:MM HH:MM"), default "sunset"
# Parameter 5: strength  (0 to 100), default 50

NIGHTSHIFT="/usr/local/bin/nightshift"
SCHEDULE="${4:-sunset}"
STRENGTH="${5:-50}"
CONSOLE_USER=$(/usr/bin/stat -f%Su /dev/console)

if [[ ! -x "$NIGHTSHIFT" ]]; then
  echo "nightshift is not installed at $NIGHTSHIFT"; exit 1
fi
if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
  echo "No user logged in, nothing to do."; exit 0
fi

USER_ID=$(/usr/bin/id -u "$CONSOLE_USER")
run_as_user() {
  /bin/launchctl asuser "$USER_ID" /usr/bin/sudo -u "$CONSOLE_USER" "$NIGHTSHIFT" "$@"
}

# shellcheck disable=SC2086
run_as_user schedule $SCHEDULE || exit 1
run_as_user strength "$STRENGTH" || exit 1
run_as_user status
