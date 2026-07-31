[CmdletBinding()]
param(
    [string]$ReportPath = (Join-Path $PWD "cacamos-windows-usb-av.txt")
)

$ErrorActionPreference = "Stop"
$targetPattern = "CaCamOS|VID_18D1&PID_4EEF"
$failures = [System.Collections.Generic.List[string]]::new()

function Get-DeviceService {
    param([Parameter(Mandatory)]$Device)

    try {
        return (Get-PnpDeviceProperty `
            -InstanceId $Device.InstanceId `
            -KeyName "DEVPKEY_Device_Service").Data
    } catch {
        return ""
    }
}

function Require-Device {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Devices,
        [string[]]$ExpectedServices = @()
    )

    $healthy = @($Devices | Where-Object Status -eq "OK")
    if ($healthy.Count -eq 0) {
        $failures.Add("$Label is missing or unhealthy")
        return
    }

    if ($ExpectedServices.Count -gt 0) {
        $services = @($healthy | ForEach-Object { Get-DeviceService $_ })
        if (@($services | Where-Object { $_ -in $ExpectedServices }).Count -eq 0) {
            $failures.Add(
                "$Label does not use an expected Windows class driver: " +
                ($services -join ", ")
            )
        }
    }
}

$allDevices = @(Get-PnpDevice -PresentOnly)
$cacamosDevices = @(
    $allDevices | Where-Object {
        $_.InstanceId -match $targetPattern -or
        $_.FriendlyName -match $targetPattern
    }
)

$composite = @(
    $cacamosDevices | Where-Object {
        $_.InstanceId -match "^USB\\VID_18D1&PID_4EEF\\"
    }
)
$camera = @(
    $cacamosDevices | Where-Object {
        $_.Class -in @("Camera", "Image") -or
        (Get-DeviceService $_) -eq "usbvideo"
    }
)
$audioControllers = @(
    $cacamosDevices | Where-Object {
        $_.Class -eq "MEDIA" -or
        (Get-DeviceService $_) -eq "usbaudio2"
    }
)
$captureEndpoints = @(
    $cacamosDevices | Where-Object {
        $_.Class -eq "AudioEndpoint" -and
        $_.InstanceId -match "\{0\.0\.1\."
    }
)
$renderEndpoints = @(
    $cacamosDevices | Where-Object {
        $_.Class -eq "AudioEndpoint" -and
        $_.InstanceId -match "\{0\.0\.0\."
    }
)

Require-Device "CaCamOS composite USB device" $composite @("usbccgp")
Require-Device "CaCamOS UVC camera" $camera @("usbvideo")
Require-Device "CaCamOS USB Audio Class 2 controller" $audioControllers @("usbaudio2")
Require-Device "CaCamOS microphone endpoint" $captureEndpoints
Require-Device "CaCamOS speaker endpoint" $renderEndpoints

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("CaCamOS Windows USB audio/video qualification")
$lines.Add("Timestamp: $(Get-Date -Format o)")
$lines.Add("")
$lines.Add("Detected devices:")

foreach ($device in ($cacamosDevices | Sort-Object Class, FriendlyName, InstanceId)) {
    $service = Get-DeviceService $device
    $lines.Add(
        "[$($device.Status)] class=$($device.Class) service=$service " +
        "name=$($device.FriendlyName) id=$($device.InstanceId)"
    )
}

$lines.Add("")
if ($failures.Count -eq 0) {
    $lines.Add("PASS: Windows bound CaCamOS webcam, microphone and speakers to built-in class drivers.")
} else {
    foreach ($failure in $failures) {
        $lines.Add("FAIL: $failure")
    }
}

$lines | Set-Content -LiteralPath $ReportPath -Encoding utf8
$lines | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Report: $ReportPath"

if ($failures.Count -ne 0) {
    exit 1
}
