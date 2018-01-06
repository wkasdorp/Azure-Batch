# Walkthrough: create Azure Batch demo with Powershell payload

## Shortcut to do the walkthrough

This Azure Batch walkthrough creates a Batch account, storage account, package, pool of VMs, and executes a job with multiple tasks to generate decimal representation of Mersenne primes. If you just want to do the walkthrough, do the following steps; if you also want the why and how, read the background information as well.  
1. Make sure you have access to an Azure subscription. You will need to type credentials of at least Contributor level.
2. Install the latest [Azure Powershell modules](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps).
3. Download the two toplevel scripts [Create-BatchAccountMersenne.ps1](https://raw.githubusercontent.com/wkasdorp/Azure-Batch/master/Create-BatchAccountMersenne.ps1) and [Create-BatchJobsAndTasks.ps1](https://raw.githubusercontent.com/wkasdorp/Azure-Batch/master/Create-BatchJobsAndTasks.ps1).
4. Run Create-BatchAccountMersenne.ps1.
5. Open the [Azure Portal](https://portal.azure.com), locate for the (default) resource group named "rg-batch-walkthrough", and inspect it a bit. 
6. Run Create-BatchJobsAndTasks.ps1. This might take a while to complete. 
7. Inspect the jobs, tasks, and task output.
8. Locate the Storage Account, File Server, a share called (default) "mersenneshare", and you should have the Mersenne primes right there. 

## Background information

This set of scripts and ZIP packages was put together to demonstrate a simple but realistic example of Azure Batch. A lot of documentation out there will show you how to set up an Azure Batch account, but the next step of packaging and executing code is often neglected.

My goal here is to set up an example that means something to the IT Pro who, like me, is familiar with PowerShell but does not write .NET code in Visual Studio every day. The nature of Azure Batch is to run code in batches distributed over a pool of VMs. So it stands to reason that you must have *some* code to run, even if you just want to test Azure Batch. Typical use cases for Azure Batch are: scientific model calculations, video rendering, data reduction, etc. 

For this example I went back to my teenage years when I was fascinated by prime number calculations, and abused my Commodore 64 with assembly code for all sorts of simple calculations. One of the earliest things I tried was to calculate the decimal representation of the largest prime number known at the time, which was 2<sup>216,091</sup>-1. This number has 65,050 digits, which makes it challenging to calculate. I had quite a bit of trouble fitting this in my 64KB Commodore 64. 

This prime number is a so-called [Mersenne Prime](https://www.mersenne.org/). Numbers of the form M=2<sup>p</sup>-1, where *p* is a prime number, have special properties making it relatively easy to tell if the number M is prime. The largest currently known prime is 2<sup>74,207,281</sup>-1, and this is indeed a Mersenne prime. 

> ### @icon-exclamation-circle New largest prime discovered!
> While I was writing this documentation, a new [Mersenne prime was discovered](https://www.mersenne.org/primes/press/M77232917.html). This prime, expressed as 2<sup>77,232,917</sup>-1, is currently (1-3-2018) the largest known prime number.

Why am I explaining this bit of trivia? Because the exercise of translating a Mersenne number to decimals requires quite a bit of calculation, especially if you want the exact number. For instance, 2<sup>107</sup>-1 = 162259276829213363391578010288127 (33 digits), while the largest known prime number (1-3-2018) has a whopping 23,249,425 digits...  

So let's say that I want to generate the decimal representation of all known Mersenne Primes. I can do this one at the time, but can also use multiple VMs simultaneously and use Azure Batch to coordinate it. Globally, this is the outline of a script to do this:
1. create an Azure Batch account, with an associated Azure Storage Account to store the packages and the results of the calculations. 
2. create a package with Powershell code to calculate Mersenne Primes.
3. create a pool of VMs with this package.
4. Start one job with a task for each of the individual Mersenne Primes, and submit this to the pool.
5. Retrieve the results. 

The essential bit of PowerShell code that does the actual work is surprisingly short. It turns out that the standard .NET framework already has the necessary modules, reducing the core of the problem to a one-liner.  
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
This is the actual calculation: `[numerics.biginteger]::pow(2,$n)-1`. The rest of the function is converting the result into human readable form. 

The walkthrough has the following files.
* *Create-BatchAccountMersenne.ps1*: Create an Azure Batch account, corresponding storage account, Mersenne package, and a pool of VMs to run the code.
* *Create-BatchJobsAndTasks.ps1*: Create a job with tasks to create the decimal representation of Mersenne Primes, indexed from 1 to 48. By default, the script calculates indexes 1-20, which happens very fast. Anything above 30 take measurable time, anything above 40 takes hours. The biggest one, 48, took me two days in my last try. 
* *Mersenne\Calculate_print_mersenne_primes.ps1*: calculate and print a Mersenne prime by index. This is the script that does the actual calculation.
* *Mersenne\generate_decimal_mersenne_and_upload.ps1*: a "glue" script that takes argument from the Azure Batch task, runs the code, and uploads the results to the Azure Storage account.
* *ZIP\MersenneV1.zip*: a ZIP package that simply contains the files from the Mersenne folder. This gets download to all VMs by the Azure Batch Package and Pool definitions. 
 
For detailed instructions, see the first section on this page. 

<small>[ in the near future, expect a link to a more detailed blogpost here ]</small> 


