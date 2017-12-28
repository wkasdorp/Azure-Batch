[CmdletBinding()]
Param
(
    # index into the Mersenne prime exponent array. 
    [Parameter(Mandatory=$true)]
    [int] $index,
    # UNC path to store the result. Could be an Azure Share
    [Parameter(Mandatory=$true)]
    [int] $uncpath,
    # account name to use for the share mapping
    [Parameter(Mandatory=$true)]
    [int] $account,
    # account password to use for the share mapping. 
    [Parameter(Mandatory=$true)]
    [int] $SaKey
)

#
# storage reference
#
#$uncpath="\\sawalkthroughpkvydrcf.file.core.windows.net\mersenneshare"
#$account="AZURE\sawalkthroughpkvydrcf"
#$SaKey = "VO82D4EtzqRmsfZCONK4Jgy+npHHX44NOK5pvv66BvULx3sOyEP8LiKLCdB+z9Utxw0I+1bLOBfHAhbC48yhhQ=="

"uncpath : '$uncpath'"
"account : '$account'"
"sakey   : '$SaKey'"

#
# files and directories
#
$batchshared = $env:AZ_BATCH_NODE_SHARED_DIR
$batchwd = $env:AZ_BATCH_TASK_WORKING_DIR
$outfile =  (Join-Path $batchwd "Mersenne-$($index).txt")

#
# tools and scripts -- full path required. Note hardcoded package name "Mersenne"
# 
$generateMersenne = "$env:AZ_BATCH_APP_PACKAGE_MERSENNE\Mersenne\calculate_print_mersenne_primes.ps1"

#
# create data. This takes a while for large Mersenne numbers. 
#
"starting to generate the Mersenne number"
&$generateMersenne -index $index > $outfile

#
# upload. Z: may exist if you have concurrent tasks. 
#
"starting upload"
If (-not (Get-SmbMapping -LocalPath Z:))
{
    New-SmbMapping -LocalPath z: -RemotePath $uncpath -UserName $account -Password $SaKey -Persistent $false 
}
Copy-Item $outfile z:

#
# debug: get all BATCH related ENV variables, output as PS commands for ENV input
#
$hostname = &hostname
get-childitem env: | Where-Object { $_.name -like "AZ_*" } | ForEach-Object {
    "`$env:$($_.name) = `"$($_.value)`""
} > (Join-Path $batchwd "$($hostname)-AZ-env.txt")

#
# finish up
#
Remove-SmbMapping -LocalPath z: -Force -ErrorAction SilentlyContinue