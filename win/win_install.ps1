param([switch]$Elevated)

function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) 
    {
        # tried to elevate, did not work, aborting
    } 
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}

exit
}

'running with full privileges'

$testchoco = powershell choco -v
if(-not($testchoco)){
    Write-Output "Seems Chocolatey is not installed, installing now"
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
else{
    Write-Output "Chocolatey Version $testchoco is already installed"
}

choco install osquery

echo "Creating temp directory..."
cd  %TEMP% && pwd && dir && git clone https://github.com/childish-gambino/osquery_deps && cd osquery_deps && ls

echo "Copying dependencies..."

copy osquery.conf com.facebook.osqueryd.plist enroll.key launcher osquery-extension.ext osquery.flags osquery.grofers.network.pem packs /var/osquery/
cd /var/osquery && ls && ls /private/var/osquery
sudo cp osquery.conf /var/osquery/osquery.conf
sudo cp com.facebook.osqueryd.plist /Library/LaunchDaemons
sudo launchctl load /Library/LaunchDaemons/com.facebook.osqueryd.plist
echo "Post installation process finished"
sudo launchctl list | grep osqueryd
kill "$revivesudo"
sudo -k


