function Connect-PureArrayGUI {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Name of the vCenter to connect in GUI.")]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string]
        $PureFQDN,

        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Credentials for the vCenter connection.")]
        [Alias("cred")]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        # Specifies a path to one or more locations.
        [Parameter(HelpMessage="Browser to use to connect to vCenter.")]
        [ValidateSet('Chrome','Edge')]
        [String]$browser = 'Chrome'
    )
    
    begin 
    {
        #this variable will be set to true if successfully authenicated to vCenter
          $authenticated = $false    
    }
    
    process 
    {
        $Driver = Open-browserSession -browser $browser -HideCommandPromptWindow -AcceptInsecureCertificates

        if( $Driver )
        {
            try 
            {
                Open-WebPage -URL "https://$PureFQDN" -Target $driver -ErrorAction Stop -ErrorVariable err
                Write-Host "WebPage for Pure Array server $PureFQDN is opened." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to connect to webpage with error $($err.Exception.Message)"
                
            }

            if( !$err )
            {
                $userName = Get-SeElement -By Id -Selection 'username' -Target $driver -Wait -ErrorAction SilentlyContinue
                    
                if( $userName )
                {
                    $userName.SendKeys( ($Credential.GetNetworkCredential()).UserName)

                    $pass = Get-SeElement -By Id -Selection 'password' -Target $driver
                    $pass.SendKeys( ($Credential.GetNetworkCredential()).Password)

                    Write-Host "Submitted credentials in webpage." -ForegroundColor Green

                    $login_button = Get-SeElement -By Id -Selection 'login-btn' -Target $Driver
                    $login_button.Click()

                    do 
                    {
                        #Measure execution time
                        $stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
                        $stopWatch.Start()

                        Start-Sleep -Seconds 2
                        $login_error = Get-SeElement -By Id -Selection 'message' -Target $Driver
                        if( $login_error.Text )
                        {
                            Write-Warning "Login failed with error [$($login_error.Text)]"
                            break
                        }
                    } while ($login_error -and $stopWatch.Elapsed.Seconds -lt 40)  

                    if ( !$login_error ) 
                    {
                        $authenticated = $true
                        Write-Host "Authentication complete." -ForegroundColor Green
                        Write-Host "Logging in to Pure Array webpage." -ForegroundColor Green
                    }       
                }
            }
        }
        else
        {
            Write-Warning "Failed to create browser connection."
        }
    }
    
    end {
        
    }
}