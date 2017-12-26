[CmdletBinding()]
Param
(
    # index into the Mersenne prime exponent array. 
    [Parameter(Mandatory=$true)]
    [int] $index
)

#
# storage reference
#
$outputUrl = "https://sawkbatch.blob.core.windows.net/output"
$sas = "?sv=2017-04-17&ss=bfqt&srt=sco&sp=rwdlacup&se=2018-10-26T06:05:34Z&st=2017-10-25T13:00:00Z&spr=https&sig=xwHOXDZR2nsWCPzx5AfENZcqrceL1drPJ1MVNMxhbS4%3D"

#
# files and directories
#
$batchshared = $env:AZ_BATCH_NODE_SHARED_DIR
$batchwd = $env:AZ_BATCH_TASK_WORKING_DIR
$outfile =  (Join-Path $batchwd "Mersenne-$($index).txt")

#
# tools and scripts -- full path required. Note hardcoded package name "Mersenne"
# 
$azcopy = "$env:AZ_BATCH_APP_PACKAGE_MERSENNE\Mersenne\azcopy\AzCopy.exe"
$generateMersenne = "$env:AZ_BATCH_APP_PACKAGE_MERSENNE\Mersenne\calculate_print_mersenne_primes.ps1"

#
# create data
#
&$generateMersenne -index $index > $outfile

# debug: get all BATCH related ENV variables, output as PS commands for ENV input
$hostname = &hostname
get-childitem env: | Where-Object { $_.name -like "AZ_*" } | ForEach-Object {
    "`$env:$($_.name) = `"$($_.value)`""
} > (Join-Path $batchwd "$($hostname)-AZ-env.txt")

#
# upload to Azure storage account. 
#
&$azcopy "/Dest:$outputUrl" "/destsas:$sas" "/source:$batchwd" /Y


