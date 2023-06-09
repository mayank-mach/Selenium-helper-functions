function Connect-vROpsGUI {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Name of the vCenter to connect in GUI.")]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string]
        $vROpsServer,

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
                Open-WebPage -URL "https://$vROpsServer/ui/login.action" -Target $driver -ErrorAction Stop -ErrorVariable err
                Write-Host "WebPage for vROps server $vROpsServer is opened." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to connect to webpage with error $($err.Exception.Message)"
                
            }

            if( !$err )
            {
                $dropDown = Get-SeElement -By Id -Selection 'authSelector-trigger-picker' -Target $driver -Wait -ErrorAction SilentlyContinue
                    
                if( $dropDown )
                {
                    Start-Sleep -Seconds 1
                    $dropDown.Click() #Open dropdown menu for the authentication sources

                    $dropDown_list = (Get-SeElement -By Id -Selection 'authSelector-picker-listEl' -Target $Driver).Text -split "`n"

                    #in case of local credentials being provided
                    if( (!$Credential.GetNetworkCredential()).Domain )
                    {
                        $domain = 'Local Users'
                    }
                    else
                    {
                        $domain = ($Credential.GetNetworkCredential()).Domain
                    }

                    if ( 
                        ( $dropDown_list -is [array] -and $dropDown_list -contains $domain ) -or 
                        ( $dropDown_list -is [string] -and $dropDown_list -eq $domain ) 
                    )
                    {
                        for($i = 1; $i -le $dropDown_list.count; $i++ )
                        {
                            $auth_source = Get-SeElement -By XPath -Selection ('//*[@id="authSelector-picker-listEl"]/ul/li['+$i+']') -Target $Driver

                            if ( $auth_source.Text -eq ($Credential.GetNetworkCredential()).Domain ) 
                            {
                                $auth_source.Click() #Selecting the auth source from drop down list
                            }
                        }
                    }
                    else 
                    {
                        Write-Warning "cannot find authentication source corresponding to domain $(($Credential.GetNetworkCredential()).Domain)"
                    }

                    $user = Get-SeElement -By Id -Selection 'userName-inputEl' -Target $driver
                    $user.SendKeys( ($Credential.GetNetworkCredential()).UserName)

                    $pass = Get-SeElement -By Id -Selection 'password-inputEl' -Target $driver
                    $pass.SendKeys( ($Credential.GetNetworkCredential()).Password)

                    Write-Host "Submitted credentials in webpage." -ForegroundColor Green

                    $login_button = Get-SeElement -By Id -Selection 'loginBtn' -Target $Driver
                    $login_button.Click()

                    do 
                    {
                        #Measure execution time
                        $stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
                        $stopWatch.Start()

                        Start-Sleep -Seconds 2
                        $login_error = Get-SeElement -By Id -Selection 'errorMsg' -Target $Driver
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
                        Write-Host "Logging in to vROps webpage." -ForegroundColor Green
                    }       
                }

                #Search for an object in vCenter
                if ($Find -and ( !$userName -or $authenticated ) ) 
                {
                    $serachButton = Get-SeElement -By Id -Selection 'top_level_object_search' -Target $driver -Wait
                    $serachButton.Click()

                    $serachBox = Get-SeElement -By Id -Selection 'top_level_object_search-inputEl' -Target $driver
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