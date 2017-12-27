# Azure-Batch
This set of scripts and ZIP packages was put together to demonstrate a simple but realistic example of Azure Batch. A lot of documentation out there will show you how to set up an Azure Batch account, but the next step of packaging and executing code is often neglected.

My goal here is to set up an example that means something to the IT Pro who, like me, is familiar with PowerShell but does not open up Visual Studio every day. The nature of Azure Batch it is to run code in batches distributed over a pool of VMs. So it stands to reason that you must have *some* code that you want to run. Typical uses are: scientific model calculations, video rendering, data reduction, etc. 

For this, I went back to my teenage years when I was fascinated by prime number calculations, and abused my Commodore 64 with assembly code for all sorts of simple calculations. The nature of prime numbers is that they can get very large very quickly. One of the earliest things I tried was to calculate the decimal representation of the largest prime number known at the time, which was 2<sup>216,091</sup>-1. This is a so-called [Mersenne Prime](https://www.mersenne.org/). Numbers of the form M=2<sup>p</sup>-1, where *p* is a prime number, have special properties making it relatively[^1] easy to tell if the number M is prime. The largest known prime, which is a Mersenne prime, currently known is 2<sup>274,207,281</sup>-1.

[^1]: Very relatively; verifying primality of Mersenne numbers requires advanced calculations. Research the [Prime95](https://www.mersenne.org/download/) program if you want to have a go. This tool is also used as a CPU stress tester.  

Why am I explaining this bit of trivia? Because the exercise if translating a Mersenn number to decimals requires quite a bit of calculation, especially if you want the exact number. For instance, 2<sup>107</sup>-1=162259276829213363391578010288127 (33 digits), but 2<sup>216,091</sup>-1 already has 65,050 digits. I had quite a bit of trouble fitting this in my 64KB Commodore 64. 

So let's say that I want to generate the decimal representation of all known Mersenne Primes. I can do this one at the time, but can also use multiple VMs at the same time, and use Azure Batch to coordinate it. Globally, this is the outline:
1. create an Azure Batch account, with an associated Azure Storage Account to store the packages and the results of the calculations. 
2. create a package with Powershell code to calculate Mersenne Primes.
3. create a pool of VMs with this package.
4. Start one job with a task for each of the individual Mersenne Primes, and submit this to the pool.
5. Retrieve the results. 

The essential bit of PowerShell code that does the actual work is suprisingly short. It turns out the the standard .NET framework already has the necessary modules. 
```powershell
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
```
There is just one line for the calculation `[numerics.biginteger]::pow(2,$n)-1`. The rest is converting the result into human readable form. 

(
- todo: list of scripts, zip file, link to the blogs. 

)



