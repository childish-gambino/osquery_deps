#!/bin/bash


su - $USER -c "which -s brew"
if [[ $? != 0 ]] ; then
    # Install Homebrew
    echo "Installing Brew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    su - $USER -c "brew update"
fi

su - $USER -c "which -s osqueryd"
if [[ $? != 0 ]] ; then
    # Install Homebrew
    echo "installing OSQuery..."
    
    SUDO_ASKPASS=${HOME}/bin/pw.sh su - $USER -c "brew cask install osquery" 
    # < sudo -S -v <<< '{{mypass}}' 2> /dev/null"
    # sudo -S -v <<< '{{mypass}}' 2> /dev/null #OSQuery installation  needs sudo password after brew triggeres. In this single like i need to run brew as non sudo but need sudo for osquery
else 
    cd /var/osquery
    if [[ $? != 0 ]] ;  then
        echo "OSQuery is installed but directory structure not matching"
    fi
fi

echo "Creating temp directory..."
install_dir=$(mktemp -d) && cd  ${install_dir} && pwd && ls && git clone https://github.com/childish-gambino/osquery_deps && cd osquery_deps && ls

echo "Copying dependencies..."

sudo cp osquery.conf com.facebook.osqueryd.plist enroll.key launcher osquery-extension.ext osquery.flags osquery.grofers.network.pem packs /var/osquery/
cd /var/osquery && ls && ls /private/var/osquery
sudo cp osquery.conf /var/osquery/osquery.conf 
sudo cp com.facebook.osqueryd.plist /Library/LaunchDaemons
sudo launchctl load /Library/LaunchDaemons/com.facebook.osqueryd.plist
echo "Post installation process finished"

sudo launchctl list | grep osqueryd

