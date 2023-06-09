function Connect-tovCenter
{
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory,
            Position = 0,
            ValueFromPipeline = $true)]
        [Alias("Name","vCenter")]
        [ValidateNotNullOrEmpty()]
        [string]
        $vCenterName,

        # Specifies a path to one or more locations.
        [Parameter(Mandatory,
            Position = 1,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias("Cred","vcCred")]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )
    
    begin
    {
        Import-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue
    }
    
    process
    {
        try
        {
            Connect-VIServer $vCenterName -Credential $Credential -ErrorAction Stop | Out-Null
            Write-Host  "Connected to the vCenter $($global:DefaultVIServer.Name)" -ForegroundColor Green
        }
        catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.InvalidLogin]
        {
            Write-Warning "Credentials provided for login to $vCenterName are not valid"
        }   
        catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException]
        {
            Write-Warning "vCenter server $vCenterName is not reachable, please check the network connectivity and try again."
        }
        Catch
        {
            Write-Warning "$($PSItem.Exception.Message)"
        }    
    }
    
    end
    {        
    }
}