function Connect-vROwebClient {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Name of the vCenter to connect in GUI.")]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string]
        $vROName,

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

        #Major version of vRO web client to connect
        [Parameter(HelpMessage="Major version of vRO web client to connect.")]
        [ValidateSet(7,8)]
        [int]$version = 7
    )
    
    begin 
    {
                
    }
    
    process 
    {
        $Driver = Open-browserSession -browser $browser -HideCommandPromptWindow -AcceptInsecureCertificates

        try 
        {
            if($version -eq 8)
            {
                $Driver.Navigate().GoToUrl("https://$($vROName)") 
                $xpath = '//*[@id="content"]/div[1]/p[3]/a'
            }
            elseif ( $version -eq 7 ) 
            {
                $Driver.Navigate().GoToUrl("https://$($vROName):8281") 
                $xpath = '//*[@id="content"]/div[3]/p[5]/a'
            }

            Write-Host "WebPage for vRealize orchestrator $vROName is opened." -ForegroundColor Green

            #Get current webpage handle and all open handles
            $currentHandle = $driver.CurrentWindowHandle
            $allHandles = $driver.WindowHandles

            #Navigate to login page
            $link = Get-SeElement -By XPath -Selection $xpath -Target $driver -wait
            $link.click()

            #Make newly opened webpage as active
            $newHandle = $driver.WindowHandles|?{$allHandles -notcontains $_}
            if($newHandle)
            {
                #Close initial webpage
                $driver.Close()

                #Navigate to newly opened webpage
                $driver.SwitchTo().Window($newHandle) | Out-Null

                #Get all available domain options and select right domain
                $domains = Get-SeElement -By Id -Selection 'userStoreDomain' -Target $driver -wait

                if ( $domains )
                {
                    $userDomain = $Credential.GetNetworkCredential().Domain

                    $domain = ($domains.Text.Split("`n")|?{$_ -like "*$userDomain*"}).trim()

                    if($domain)
                    {
                        Write-Host "Selected Domain $domain for authentication"
                        $domains.SendKeys($domain)

                        $remember = Get-SeElement -By Id -Selection remember -Target $driver
                        $remember.Click() #unChecking the remember domain selection option to ease in automation.

                        (Get-SeElement -By Id -Selection 'userStoreFormSubmit' -Target $driver).click()
                    }
                }
                
                $userSection = Get-SeElement -By Id -Selection 'username' -Target $driver -wait

                if ( $userSection )
                {
                    #Authentication step
                    Write-Host "Authenticating with vRO"
                    $userSection.SendKeys($Credential.GetNetworkCredential().UserName)

                    (Get-SeElement -By Id -Selection 'password' -Target $driver).SendKeys($Credential.GetNetworkCredential().Password)

                    Write-Host "Logging in to vRO web client"
                    (Get-SeElement -By Id -Selection 'signIn' -Target $driver).click()

                    $authentication_error = Get-SeElement -By XPath -Selection '[@id="loginForm"]/div/div[1]/div[2]/fieldset/div[5]' -Target $driver -Timeout 5

                    if( $authentication_error )
                    {
                        Write-Warning "vRO login failed with error $($authentication_error.Text)"
                    }
                } 
                else
                {
                    Write-Warning "Domain name $userDomain is not an identity source for vRO."
                }
            }  
            else
            {
                Write-Warning "Failed to load authenitcation webpage for vRO $vROName"
            }       
        }
        catch {
            #if webpage failed to load
            if ($_.exception.innerexception -match 'ERR_CONNECTION_TIMED_OUT') {
                Write-Warning "Failed to connect to the vRO server, check vRO network connectivity."
            }
        }
        finally {
            $ErrorActionPreference = 'Continue'
        }
    }
    
    end {
        
    }
}