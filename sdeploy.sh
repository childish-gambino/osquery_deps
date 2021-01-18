#!/bin/bash
# set -e
set -u
set -x

while :; do
    echo "###gotta keep sudo alive###"
    sudo -v
    sleep 256
done &
revivesudo=$!

function cleanup() {
    sudo -l -U "$(id -u -n)"
    kill $revivesudo
    sudo -k
}
trap cleanup EXIT

which -s brew
if [[ $? != 0 ]]; then
    # Install Homebrew
    echo "Installing Brew..."
    # yes "" | ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    yes "" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    brew update
fi

which -s osqueryd
if [[ $? != 0 ]]; then
    # Install Homebrew
    echo "installing osquery..."
    brew --cask install osquery
else
    cd /var/osquery
    if [[ $? != 0 ]]; then
        echo "osquery is installed but directory structure not matching"
    fi
fi

echo "Creating temp directory..."
install_dir=$(mktemp -d) && cd ${install_dir} && pwd && ls && git clone https://github.com/childish-gambino/osquery_deps && cd osquery_deps && ls

echo "Copying dependencies..."

sudo cp osquery.conf com.facebook.osqueryd.plist enroll.key launcher osquery-extension.ext osquery.flags osquery.grofers.network.pem /var/osquery/ || True
cd /var/osquery && ls && ls /private/var/osquery
sudo cp osquery.conf /var/osquery/osquery.conf || True
sudo cp com.facebook.osqueryd.plist /Library/LaunchDaemons || True
sudo launchctl load /Library/LaunchDaemons/com.facebook.osqueryd.plist || True
echo "Post installation process finished"
sudo launchctl list | grep osqueryd

# Checking host on Fleet Server
brew install jq
brew install curl

echo "Checking host on Fleet Server..."

request=$(sudo osqueryi --json "SELECT uuid FROM system_info" | jq -r '.[].uuid')
echo "uuid on local: \n $request"

# Remove curl alias on windows.
# Remove-Item alias:curl

set +x
# response=$(curl -k -sS -X GET 'https://osquery.grofers.network/api/v1/kolide/hosts' -H 'authorization: Bearer' '"$token"' | jq -r --arg uuid "$request" '.[] | map(select(.uuid | contains($uuid)))|.[].uuid')

response=$(curl -k -sS -X GET "https://osquery.grofers.network/api/v1/kolide/hosts" -H "${2}" | jq -r --arg uuid "$request" '.[] | map(select(.uuid | contains($uuid)))|.[].uuid')

# json=sudo osqueryi --json "SELECT uuid, hostname, computer_name, hardware_serial  FROM system_info"|awk '/{([^}]*})/ {print $0}'|sed 's/^ *//g'

# json=$(jq -n --arg res "$res" '{ "hostid": $res, "email": "$1", "serialnumber": "$sr" }')

echo "Logging rollout progress..."

json=$(sudo osqueryi --json "SELECT uuid, hostname, computer_name, hardware_serial  FROM system_info" | awk '/{([^}]*})/ {print $0}' | sed 's/^ *//g' | jq --arg email "$1" '. + {"email": $email, "status": "err"}')

echo "This is the json body \n $json"

if [[ $request == $response ]]; then
    echo "Host successfully enrolled!"
    json=$(jq '. + {"status": "ok"}' <<<"$json")
    curl -X POST -H 'Content-Type: application/json' -d "$json" https://certitude.grofers.network/api/
    echo "Hakuna Mtata!!"
else
    echo "There was problem with enrolling this host"
    echo "Local uuid:\n $request is not equal to \n $response"
    json=$( (jq '. + {"uuid": ""}' <<<"$json"))
    curl -X POST -H 'Content-Type: application/json' -d "$json" https://certitude.grofers.network/api/
fi
