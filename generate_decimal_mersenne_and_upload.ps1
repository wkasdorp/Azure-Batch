[CmdletBinding()]
Param
(
    # index into the Mersenne prime exponent array. 
    [Parameter(Mandatory=$true)]
    [int] $index,
    # UNC path to store the result. Could be an Azure Share
    [Parameter(Mandatory=$true)]
    [string] $uncpath,
    # account name to use for the share mapping
    [Parameter(Mandatory=$true)]
    [string] $account,
    # account password to use for the share mapping. 
    [Parameter(Mandatory=$true)]
    [string] $SaKey
)

#
# files and directories
#
$batchshared = $env:AZ_BATCH_NODE_SHARED_DIR
$batchwd = $env:AZ_BATCH_TASK_WORKING_DIR
$outfile =  (Join-Path $batchwd "Mersenne-$($index).txt")

#
# tools and scripts -- full path required. Note hardcoded package name "Mersenne"
# 
$generateMersenne = "$env:AZ_BATCH_APP_PACKAGE_MERSENNE\calculate_print_mersenne_primes.ps1"

#
# create data. This takes a while for large Mersenne numbers. 
#
"starting to generate the Mersenne number"
&$generateMersenne -index $index > $outfile

#
# upload. Z: may exist if you have concurrent tasks. 
#
"starting upload"
If (-not (Get-SmbMapping -LocalPath Z: -ErrorAction SilentlyContinue))
{
    New-SmbMapping -LocalPath z: -RemotePath $uncpath -UserName $account -Password $SaKey -Persistent $false 
}
Copy-Item $outfile z:

#
# finish up
#
Remove-SmbMapping -LocalPath z: -Force -ErrorAction SilentlyContinue