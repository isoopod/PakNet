# We want to make sure Rojo is not Live-Syncing because it will cause an error
$port = 34872 # Default Rojo port
$client = New-Object System.Net.Sockets.TcpClient
$async = $client.BeginConnect("localhost", $port, $null, $null)
$success = $async.AsyncWaitHandle.WaitOne(1)

if ($success -and $client.Connected) {
    $client.Close()
    Write-Warning "Stop your Rojo Live-Sync server before running this script."
} else {
    # Remove old packages folders
    # This allows us to use caret versions
    if (Test-Path -Path "Packages" -PathType Container) {
        Remove-Item -Path "Packages" -Recurse -Force
    }
    if (Test-Path -Path "ServerPackages" -PathType Container) {
        Remove-Item -Path "ServerPackages" -Recurse -Force
    }

    wally install

    rojo sourcemap --output sourcemap.json default.project.json

    wally-package-types --sourcemap sourcemap.json Packages/
    wally-package-types --sourcemap sourcemap.json ServerPackages/
}