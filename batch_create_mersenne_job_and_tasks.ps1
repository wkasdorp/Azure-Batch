﻿# Requirements: existing batch account, one active pool with Windows machines, app registered on the batch account 
$VerbosePreference="Continue"

#
# adjustable parameters for the job and tasks.
#
$firstindex = 1
$lastindex = 10 # current maximum index.
$jobnamePrefix = "mersenne-job"
$tasknameprefix = "task"

#
# define names. Be careful changing these.
#
$Applicationname = "Mersenne"
$ResourceGroupName = "rg-batch-walkthrough"
$BatchAccountNamePrefix = "walkthrough"

#
# helper function to create a unique ID from a resource ID
#
function Get-LowerCaseUniqueID ([string]$id, $length=8)
{
    $hashArray = (New-Object System.Security.Cryptography.SHA512Managed).ComputeHash($id.ToCharArray())
    -join ($hashArray[1..$length] | ForEach-Object { [char]($_ % 26 + [byte][char]'a') })
}



#
# get the batch account. Note that its name derives from the Resource Group ID, which contains the unique subscription GUID. 
#
Write-Verbose "Getting the Resource Group and Batch Account"
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction stop
$BatchAccountName = $BatchAccountNamePrefix + (Get-LowerCaseUniqueID -id $ResourceGroup.ResourceId)
$batchaccount = Get-AzureRmBatchAccount | Where-Object { $_.AccountName -eq $batchaccountName } -ErrorAction stop
$batchkeys = $batchaccount | Get-AzureRmBatchAccountKeys

#
# Read the storage account and the shared folder object. Get the key 
# for later use by the Batch Application.
#
$StorageAccountName = "sa$($BatchAccountName)"
Write-Verbose "Reading Storage account '$StorageAccountName', its key, and the share configuration" 
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction stop
$StorageKey = ($StorageAccount | Get-AzureRmStorageAccountKey)[0].Value
$Share = Get-AzureStorageShare -Name $ShareName -Context $StorageAccount.Context
$uncPath = $Share.Uri -replace 'https://','\\' -replace '/','\'
$shareAccount = "AZURE\$($StorageAccount.StorageAccountName)"

#
# get the active  VM pool (requirement: there should be exactly one such pool)
#
Write-Verbose "Looking for an active Pool in the batch account $BatchAccountName"
$pool = Get-AzureBatchPool -BatchContext $batchkeys | Where-Object { $_.State -eq "Active" }
$PoolInformation = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSPoolInformation" 
$PoolInformation.PoolId = $pool.Id 
if (-not $pool.ApplicationPackageReferences) {
    Write-Warning "Warning: pool has no packages. Do you need to add any application package references to the pool before starting tasks?"
}

#
# create a job with a name based on current time. 
#
$jobnamePostfix = (Get-Date -Format s) -replace ':', ''
$jobname = "$jobnamePrefix-$jobnamePostfix"
Write-Verbose "Creating job $jobname ..." 
New-AzureBatchJob -BatchContext $batchkeys -Id $jobname -PoolInformation $PoolInformation -ErrorAction Stop

#
# start create tasks. Restrict to maximum of 3 execution retries. 
#
Write-Verbose "creating tasks for Mersenne exponents $firstindex to $lastindex ..."
$taskPostfix = Get-Random -Minimum 0 -Maximum 1000000
$constraints = New-Object Microsoft.Azure.Commands.Batch.Models.PSTaskConstraints -ArgumentList @($null,$null,3)
#
# deploy the default or the latest version of the app explicitly in the task. 
# We do this instead of depending on a app reference of the pool to avoid possible reboots of the nodes.
#
$batchapp = Get-AzureRmBatchApplication -AccountName $batchaccountName -ResourceGroupName $batchaccount.ResourceGroupName -ApplicationId $Applicationname -ErrorAction stop
$version = if (-not $batchapp.DefaultVersion) { $batchapp.ApplicationPackages[-1].Version } else { $batchapp.DefaultVersion}
$appref = New-Object Microsoft.Azure.Commands.Batch.Models.PSApplicationPackageReference
$appref.ApplicationId = $batchapp.id
$appref.Version = $version
$firstindex..$lastindex  | ForEach-Object {
    $ps1file =  "%AZ_BATCH_APP_PACKAGE_MERSENNE#$($version)%\generate_decimal_mersenne_and_upload.ps1"
    # $taskCMD = "cmd /c `"powershell -executionpolicy bypass -File $ps1file -index $_`""
    $taskCMD = "cmd /c `"powershell -executionpolicy bypass -File $ps1file -index $_ -uncpath $uncPath -account $shareAccount -sakey $StorageKey`""
    $taskName = "$tasknameprefix-$_-$taskPostfix"
    Write-Verbose "- submitting task '$taskname' to job '$jobname'"
    Write-Verbose "- DEBUG taskCMD: '$taskCMD'"
  
--------curreent error
C:\user\tasks\applications\wd\mersenne\1.0\2017-12-26T22.41.36.169Z\generate_de
cimal_mersenne_and_upload.ps1 : Cannot process argument transformation on 
parameter 'uncpath'. Cannot convert value 
"\\sawalkthroughpkvydrcf.file.core.windows.net\mersenneshare" to type 
"System.Int32". Error: "Input string was not in a correct format."
    + CategoryInfo          : InvalidData: (:) [generate_decimal_mersenne_and_ 
   upload.ps1], ParentContainsErrorRecordException
    + FullyQualifiedErrorId : ParameterArgumentTransformationError,generate_de 
   cimal_mersenne_and_upload.ps1
  
    
    New-AzureBatchTask -JobId $jobname -BatchContext $batchkeys -CommandLine $taskCMD -Id $taskname -Constraints $constraints -ApplicationPackageReferences $appref
}

#
# wait for tasks to finish while supplying some output. 
#
Write-Verbose "Now waiting for tasks to complete"                  
Write-Host "waiting for tasks to complete..." -ForegroundColor Cyan
do {
    $stats = Get-AzureBatchTask -BatchContext $batchkeys -JobId $jobname -Verbose:$false | Group-Object -NoElement state
    $stats | Format-Table
    $ready = ($stats.Values -notcontains "Active") -and ($stats.Values -notcontains "Running")
    if (-not $ready) { Start-Sleep -Seconds 3 }
} until ($ready)

#
# terminate the job and any remaining tasks. 
#
Write-Verbose "Terminating job $jobname"
Stop-AzureBatchJob -id $jobname -BatchContext $batchkeys
