[CmdletBinding()]
Param
(
    # index into the Mersenne prime exponent array. 
    [Parameter(Mandatory=$true)]
    [int] $index
)

$MersenneExponents = @(
    2, 3, 5, 7, 13,
    17, 19, 31, 61, 89,
    107, 127, 521, 607, 1279,
    2203, 2281, 3217, 4253, 4423,
    9689, 9941, 11213, 19937, 21701,
    23209, 44497, 86243, 110503, 132049,
    216091, 756839, 859433, 1257787, 1398269,
    2976221, 3021377, 6972593, 13466917, 20996011,
    24036583, 25964951, 30402457, 32582657, 37156667,
    42643801, 43112609, 57885161, 74207281
)
if ($index -ge $MersenneExponents.Count) {
    throw { "Maximum index for Mersenne exponent array exceeded." }
}

function PrintMersenneDecimal ([int] $n, $width = 80)
{
    $prime = [numerics.biginteger]::pow(2,$n)-1
    $s = $prime.ToString()
    "Mersenne prime 2^$n-1 has $($s.length) digits."
    for ($n=0; $n -lt $s.length; $n += $width)
    {
       $s.Substring($n, [math]::min($width, $s.Length - $n))
    }    
}

# you can easily change this to a range :)
$MersenneExponents[$index] | ForEach-Object {
    $stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
    $stopWatch.Start()
    $decimalPrime = PrintMersenneDecimal $_ 
    $stopWatch.Stop()
    Write-Host "Generating Mersenne prime #$($index) with exponent $_ took $($stopWatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Yellow
    $decimalPrime
} 
