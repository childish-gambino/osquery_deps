param(
    [string]$em
)
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    # if ($elevated) {
    #     # tried to elevate, did not work, aborting
    # } 
    # else {
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    # }

    # exit
}

'running with full privileges'

Write-Output "############ HELLO FELLOW NERD ############ `n `n"
$token = Read-Host -Prompt "Please enter your security token"
Write-Output $email

Write-Output "`n"

$email = Read-Host -Prompt "Please enter your Grofers/HOT email ID"
Write-Output $email
# $hostname=$email.split("@")[0]
Set-PSDebug -Trace 1
$domain = $email.split("@")[1]
switch ($domain) {
    "grofers.com" {
        $hostname = $email.replace("@grofers.com", "-gipl")
        $hostname = $hostname.replace(".", "-")
        break
    }

    "handsontrades.com" {
        $hostname = $email.replace("@handsontrades.com", "-hot")
        $hostname = $hostname.replace(".", "-")
        break
    }
}
Write-Output $hostname
# $srn = (wmic bios get serialnumber | findstr /I /V "SerialNumber" | out-string).trim()
# $hostname += "-" + $srn
# Write-Output $hostname

rename-computer -newname "$hostname" -force

if (test-path "C:\ProgramData\chocolatey\choco.exe") {
    Write-Output "Choco is already installed"
}
else {
    Write-Output "Seems Chocolatey is not installed, installing now"
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}


osqueryi --version
if (-not($?)) {
    Write-Output "Will install osquery now!"
    choco install -y osquery --force
}

Set-Location "c:\Program Files\osquery"
if ($?) {
    Write-Output "Talking to osquery..."
}
else {
    Write-Output "Could not locate osquery installation"
}

git --version
if (-not($?)) {
    Write-Output "Installing Git..."
    choco install -y git
}


Write-Output "Cloning osquery dependencies..."
$wdir = Get-Location
Write-Output $wdir

# need to create an alias for git since ps wouldnt recognize git installation within the same session

New-Item -path alias:git -value 'C:\Program Files\Git\bin\git.exe'


git clone "https://github.com/childish-gambino/osquery_deps"
Set-Location "c:\Program Files\osquery\osquery_deps"
Write-Output "Installing osquery dependencies..."

# copy source osquery.conf+enroll.key+launcher+osquery-extension.ext+osquery.flags+osquery.grofers.network.pem destination "c:\Program Files\osquery"
Copy-Item -Path .\win\osquery_win.conf, .\enroll.key, .\launcher, .\osquery-extension.ext, .\win\osquery_win.flags, .\osquery.grofers.network.pem -Destination "c:\Program Files\osquery"
Set-Location ..
# If there's an existing osqueryd service...uninstall
Get-Service osqueryd
if ($?) {
    .\manage-osqueryd.ps1 -uninstall
}
Write-Output "Deploying osquery daemon..."

# .\manage-osqueryd.ps1 -install -startupArgs "C:\Program Files\osquery\osquery_win.flags"
New-Service -Name "osqueryd" -BinaryPathName "C:\Program Files\osquery\osqueryd\osqueryd.exe --flagfile=`"C:\Program Files\osquery\osquery_win.flags`""
# .\manage-osqueryd.ps1 -startupArgs

Write-Output "Will try to start osquery daemon but cannot guarantee..."
Start-Service osqueryd
# .\manage-osqueryd.ps1 -installWelManifest
Get-Service osqueryd
Write-Output "Enabling Windows Event Log support..."
wevtutil im "C:\Program Files\osquery\osquery.man"


# Checking host on Fleet Server
choco install -y jq
choco install -y curl

Write-Output "Checking host on Fleet Server..."

$request = osqueryi --json "SELECT uuid FROM system_info" | jq -r ".[].uuid"
Write-Output "uuid on local: `n $request"

Remove-Item alias:curl

$response = curl -sS -k -X GET "https://osquery.grofers.network/api/v1/kolide/hosts" -H "authorization: Bearer $token" | jq -r --arg request \`"$request\`" ".[] | map(select(.uuid | contains(\`"$request\`")))|.[].uuid"
Write-Output "uuid on remote: `n $response"


# json=sudo osqueryi --json "SELECT uuid, hostname, computer_name, hardware_serial  FROM system_info"|awk '/{([^}]*})/ {print $0}'|sed 's/^ *//g'

# json=$(jq -n --arg res "$res" '{ "hostid": $res, "email": "$1", "serialnumber": "$sr" }')


Write-Output "Logging rollout progress..."

$json = osqueryi --json "SELECT uuid, hostname, computer_name, hardware_serial  FROM system_info" | jq --arg email \`"$email\`" ".[] |. + {\`"email\`": \`"$email\`", \`"status\`": \`"err\`"}"

Write-Output "DEBUG: Default JSON body `n $json"

$jdata = @{
    uuid            = $json | jq -r ".uuid"
    hostname        = $json | jq -r ".hostname"
    computer_name   = $json | jq -r ".computer_name"
    hardware_serial = $json | jq -r ".hardware_serial"
    email           = $email
    status          = "err"
}
$uri = 'https://certitude.grofers.network/api/'

if ( $request -eq $response ) {
    Write-Output "Host successfully enrolled!"

    # $json=write-output $json |jq ". + {\`"status\`": \`"ok\`"}"
    $jdata['status'] = "ok"
    Write-Output "DEBUG: JSON after changing <err>"
    Write-Output "$json"
    Write-Output "Getting ready for curl..."
    # $json=$json
    write-output "$json"
    # curl -X POST -H 'Content-Type: application/json' -d "$json" https://certitude.grofers.network/api/
    Invoke-RestMethod -Uri $uri -Method Post -Body ($jdata | ConvertTo-Json) -ContentType "application/json"
    Write-Output "Hakuna Mtata!!"
}
else {
    Write-Output "There was problem with enrolling this host"
    Write-Output "Local uuid:`n $request is not equal to `n $response"
    $json = write-output $json | jq ". + {\`"uuid\`": \`"\`"}"
    Invoke-RestMethod -Uri $uri -Method Post -Body ($jdata | ConvertTo-Json) -ContentType "application/json"

    # curl -X POST -H "Content-Type: application/json" -d "$json" https://certitude.grofers.network/api/
}
