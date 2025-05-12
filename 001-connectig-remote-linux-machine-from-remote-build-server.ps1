$servers1 = "3.15.31.185,3.15.31.185"   # enter server name of ip or fqdn
$servers = $servers1 -split ','    
$username = "ubuntu"                   # enter the username make sure if you have multipe server should have the same username in all te servver
$password = "12345"                    # enter the username make sure if you have multipe server should have the same username in all te servver
$command = "ls -l /"  # enter the command or liux bash script path as--> "sudo sh /file/path/filename.sh"

$secPass = $password | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object PSCredential($username, $secPass)



foreach ($remoteIp in $servers) {
    Write-Host ("Connecting to {0}..." -f $remoteIp)

    Try {
        $session = New-SSHSession -ComputerName $remoteIp -Credential $credential -AcceptKey -ConnectionTimeout 50000

        $result = Invoke-SSHCommand -SSHSession $session -Command $command -Timeout 10000


        if ($result.ExitStatus -ne 0) {
            $errorMessage = "Command failed on $remoteIp with ExitStatus $($result.ExitStatus). Error output:`n$($result.Error -join "`n")"
            throw $errorMessage
        } else {
            Write-Host ("Command output from {0}:`n{1}" -f $remoteIp, ($result.Output -join "`n"))
        }
    }
    Catch {
        Write-Error ("Execution error on {0}: {1}" -f $remoteIp, $_.Exception.Message)
    }
    Finally {
        if ($session) {
            $session | Remove-SSHSession | Out-Null
        }
    }
}
