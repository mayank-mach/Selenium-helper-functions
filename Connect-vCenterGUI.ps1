function Connect-vCenterGUI {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Name of the vCenter to connect in GUI.")]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string]
        $vCenterName,

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
        [String]$browser = 'Chrome',

        # Specifies a path to one or more locations.
        [Parameter(HelpMessage="Item to find in vCenter.")]
        [ValidateNotNullOrEmpty()]
        [String]$Find
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
                Open-WebPage -URL "https://$vCenterName/ui/" -Target $driver -ErrorAction Stop -ErrorVariable err
                Write-Host "WebPage for vCenter $vCenterName is opened." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to connect to webpage with error $($err.Exception.Message)"
                
            }

            if( !$err )
            {
                $userName = Get-SeElement -By Id -Selection 'username' -Target $driver -Wait -ErrorAction SilentlyContinue
                    
                if( $userName )
                {
                    $userName.SendKeys("$($Credential.UserName.tostring())")

                    $passwd = Get-SeElement -By Id -Selection 'password' -Target $driver -Wait
                    $passwd.SendKeys("$($Credential.GetNetworkCredential().Password.tostring())")

                    Write-Host "Submitted credentials in webpage." -ForegroundColor Green

                    $click = Get-SeElement -By Id -Selection 'submit' -Target $driver -Wait
                    $click.Click()

                    do 
                    {
                        #Measure execution time
                        $stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
                        $stopWatch.Start()

                        Start-Sleep -Seconds 2
                        $login_error = Get-SeElement -By Id -Selection 'response' -Target $driver -ErrorAction SilentlyContinue
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
                        Write-Host "Logging in the vCenter webpage." -ForegroundColor Green
                    }       
                }

                #Search for an object in vCenter
                if ($Find -and ( !$userName -or $authenticated ) ) 
                {
                    $serachBox = Get-SeElement -By Id -Selection 'search-term-ref' -Target $driver -Wait
                    $serachBox.SendKeys("$Find") 
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