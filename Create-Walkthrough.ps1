# This walkthrough was adapted from: https://docs.microsoft.com/en-us/azure/batch/batch-powershell-cmdlets-get-started 

#
# preliminary stuff: log on to azure, enable verbosity to see what is happening. Edit as you see fit. 
#
Add-AzureRmAccount
$VerbosePreference="Continue"

#
# define names.
#
$ResourceGroupName = "rg-batch-walkthrough"
$Region = "Central US"
$BatchAccountNamePrefix = "walkthrough"

#
# don't touch these unless you know what you are doing. 
#
$Applicationname = "Mersenne"
$PoolName = "Pool1"
$ShareName ="mersenneshare"
$Nodecount = 2
$PackageURL = "https://github.com/wkasdorp/Azure-Batch/raw/master/ZIP/MersenneV1.zip"

#
# helper function to create a unique ID from a resource ID
#
function Get-LowerCaseUniqueID ([string]$id, $length=8)
{
    $hashArray = (New-Object System.Security.Cryptography.SHA512Managed).ComputeHash($id.ToCharArray())
    -join ($hashArray[1..$length] | ForEach-Object { [char]($_ % 26 + [byte][char]'a') })
}

#
#
# get or create the resource group. 
#
$ResourceGroup = $null
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if ($ResourceGroup -eq $null)
{
    Write-Verbose "creating new resource group: $ResourceGroupName"
    $ResourceGroup = New-AzureRmResourceGroup –Name $ResourceGroupName -Location $Region -ErrorAction Stop
}

#
# Create a batch account if it does not exist.
# A batch account must be worldwide unique. Generate name based on resource group ID: static but unique. 
#
$BatchAccountName = $BatchAccountNamePrefix + (Get-LowerCaseUniqueID -id $ResourceGroup.ResourceId)
$StorageAccountName = "sa$($BatchAccountName)"
$BatchAccount = $null
$BatchAccount = Get-AzureRmBatchAccount –AccountName $BatchAccountName –ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($BatchAccount -eq $null)
{
    #
    # we need a storage account to store packages, again with a unique name.
    #
    Write-Verbose "Creating new storage account for use with batch: $StorageAccountName"
    $StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -SkuName Standard_LRS -Location $Region -Kind Storage

    #
    # we will use an SMB share to read/write our data from the batch nodes.
    #
    Write-Verbose "Creating new shared folder in the storage account account: $ShareName"
    $Share = New-AzureStorageShare -Context $StorageAccount.Context -Name $ShareName

    #
    # create the batch account, associated it with the storage account
    #
    Write-Verbose "Creating new batch account: $BatchAccountName"
    $BatchAccount = New-AzureRmBatchAccount –AccountName $BatchAccountName –Location $Region –ResourceGroupName $ResourceGroupName -AutoStorageAccountId $StorageAccount.Id
}

#
# Read the storage account and the shared folder object. Get the key 
# for later use by the Batch Application.
#
Write-Verbose "Reading Storage account, its key, and the share configuration" 
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName 
$StorageKey = ($StorageAccount | Get-AzureRmStorageAccountKey)[0].Value
$Share = Get-AzureStorageShare -Name $ShareName -Context $StorageAccount.Context
$uncPath = $Share.Uri -replace 'https://','\\' -replace '/','\'
$shareAccount = "AZURE\$($StorageAccount.StorageAccountName)"

#
# Get the context of the batch account; this part contains the keys.
#
$BatchContext = Get-AzureRmBatchAccountKeys -AccountName $BatchAccountName -ResourceGroupName $ResourceGroupName 

#
# create an application with one package. This is convenient when creating the pool. 
# First, get the ZIP containing the package.
#
$tempfile = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } –PassThru
Write-Verbose "Downloading application package '$PackageURL' to '$tempfile'"
Invoke-WebRequest -Uri $PackageURL -OutFile $tempfile 

Write-Verbose "Creating new batch application: $applicationname"
New-AzureRmBatchApplication -AccountName $BatchAccountName -ResourceGroupName $ResourceGroupName -ApplicationId $applicationname

Write-Verbose "Adding new package $(Split-Path $PackageURL -Leaf) to application $applicationname"
New-AzureRmBatchApplicationPackage -AccountName $BatchAccountName -ResourceGroupName $ResourceGroupName -ApplicationId $applicationname `
    -ApplicationVersion "1.0" -Format zip -FilePath $tempfile 

Write-Verbose "Setting default version for $applicationname to 1.0"
Set-AzureRmBatchApplication -AccountName $BatchAccountName -ResourceGroupName $ResourceGroupName -ApplicationId $applicationname -DefaultVersion "1.0"

#
# create a pool of VMs with the application preinstalled. This will take a while to initialize, 15m is usual. 
#
$appPackageReference = New-Object Microsoft.Azure.Commands.Batch.Models.PSApplicationPackageReference
$appPackageReference.ApplicationId = $applicationname
$appPackageReference.Version = "1.0"

Write-Verbose "Creating new pool named: $PoolName. It has $Nodecount Windows nodes."
$PoolConfig = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSCloudServiceConfiguration" -ArgumentList @(4,"*")
New-AzureBatchPool -Id $PoolName -VirtualMachineSize "Small" -CloudServiceConfiguration $PoolConfig `
    -BatchContext $BatchContext -ApplicationPackageReferences $appPackageReference -TargetDedicatedComputeNodes $Nodecount

@"
todo:
- change mersenne runs cript to read UNC, SA name, en SA key
- change mersenne to write to share
- create JOb
- create task with extra CMD args
   
"@
