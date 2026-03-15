Skip to content
You said:
string is null or empty
ChatGPT said:
In PowerShell, to check if a string is null or empty, you can use the [string]::IsNullOrEmpty() method, which is part of the .NET framework. Here's how to use it:

✅ Syntax
[string]::IsNullOrEmpty($yourString)
✅ Example
$myString = ""

if ([string]::IsNullOrEmpty($myString)) {
Write-Host "String is null or empty"
} else {
Write-Host "String has value"
}
🧠 Tip: Also Checking for Whitespace
If you want to check if a string is null, empty, or only whitespace, use [string]::IsNullOrWhiteSpace():

[string]: :IsNullOrWhiteSpace($yourString)

This is often better in validation logic where a space " " should also be considered "empty."

Let me know if you want to wrap this into a reusable function or test it with Pester!

You said:
parameter validation non null or empty or whatespace
ChatGPT said:
To enforce parameter validation in a PowerShell function such that a string cannot be null, empty, or whitespace, you can use a combination of [ValidateScript()] with [string]::IsNullOrWhiteSpace().

✅ Example: Parameter Validation
function Set-Username {
param (
[Parameter(Mandatory)]
[ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$Username
)

    Write-Host "Username is: $Username"

}
🧪 Usage
Set-Username -Username "JohnDoe" # ✅ Works
Set-Username -Username "" # ❌ Fails
Set-Username -Username " " # ❌ Fails
Set-Username # ❌ Fails due to Mandatory
🧠 Why It Works
[ValidateScript()] lets you run arbitrary logic to determine if a parameter is valid.

-not [string]::IsNullOrWhiteSpace($\_) ensures the string isn't null, empty, or whitespace.

Would you like a reusable attribute class to simplify this pattern for multiple parameters?

You said:
Register-PSRepository for an http feed using PSResourceGet and v3
ChatGPT said:
To register a PowerShell repository that uses HTTP (non-HTTPS) with Register-PSResourceRepository (from PSResourceGet v3+), you need to bypass the default HTTPS requirement since PSResourceGet enforces secure feeds by default.

✅ Steps for PSResourceGet v3+ using HTTP Feed

1. ⚠️ Allow Unsecured Feeds
   You must explicitly allow HTTP feeds using the -Trusted and -AllowUnsecureConnection flags.

2. 🧩 Register Repository Command
   Register-PSResourceRepository `    -Name "MyHttpRepo"`
   -Url "http://myserver.local/nuget" `    -Trusted`
   -AllowUnsecureConnection `    -PublishLocation "http://myserver.local/nuget"`
   -ScriptSourceLocation "http://myserver.local/nuget" `
   -PackageManagementProvider "NuGet"
   🔍 Parameters Explained
   Parameter Description
   -Name Friendly name of the repo.
   -Url Base URL for the NuGet feed.
   -Trusted Required for untrusted HTTP endpoints.
   -AllowUnsecureConnection Overrides default HTTPS-only requirement.
   -PublishLocation Where modules will be pushed.
   -ScriptSourceLocation Where script packages will be pulled from.
   -PackageManagementProvider Usually "NuGet" (use Get-PackageSource to confirm).
   ❗ Note
   This only works with PowerShellGet v3 / PSResourceGet — not with older Register-PSRepository.

Make sure your NuGet server supports HTTP-based publishing and searching.

If you're behind a proxy/firewall, test with Invoke-WebRequest first to ensure it's reachable.

Would you like a full module publishing example using this feed?

No file chosenNo file chosen
ChatGPT can make mistakes. Check important info.
