# TEsting within the ATAP.Utilities repository

## Pester Testing for Powershell

The tests/

When dealing with Pester tests for PowerShell functions that load a .DLL, it's essential to segregate and manage tests that require a fresh process (due to a DLL change) versus those that don't. Here are some suggestions to recognize and organize such tests:

Directory Organization:

Organize your tests into separate directories, e.g., RequiresNewProcess and RegularTests.
Inside the RequiresNewProcess directory, you can further categorize based on the DLLs if you have multiple DLLs. Each subdirectory can be the name of the DLL. This makes it clear which tests are related to which DLLs.
Test File Naming Convention:

Adopt a naming convention for your test files. For instance, any test file that needs to be run in a new process because of a DLL could be prefixed with NewProcess_ or suffixed with _NewProcess. This way, by just looking at the file name, you know the nature of the test.
Tags in Describe Blocks:

Use the -Tag parameter in the Describe block of Pester tests. You can tag tests that require a new process with 'NewProcess' and others with 'Regular'.
powershell
Copy code
Describe "MyFunction Test" -Tag NewProcess {
    # tests that need a new process
}

Describe "AnotherFunction Test" -Tag Regular {
    # regular tests
}
With tags, you can selectively run tests:

powershell
Copy code
Invoke-Pester -Tag NewProcess  # runs only tests that require a new process
DLL Version Tracking:

Track the version or timestamp of the DLL when it's tested. Store this in a configuration or a log file.
Before running tests, check the DLL's current version or timestamp against the logged version. If there's a change, you know you need to run the RequiresNewProcess tests.
Automate with a Script:

Write a PowerShell script to automate the above checks. This script can:
Check the DLL's version or timestamp.
Compare it with the logged version.
If different, invoke the tests from the RequiresNewProcess directory using Invoke-Pester.
If the same, invoke the tests from the RegularTests directory.
Use -RunInNewProcess Parameter:

If a test requires a new process, leverage Pester's -RunInNewProcess parameter:
powershell
Copy code
Invoke-Pester -Path .\RequiresNewProcess\MyTest.Tests.ps1 -RunInNewProcess

Documentation:

Ensure there's adequate documentation for your tests. If someone new comes on board or if you're revisiting your tests after a long time, clear documentation can save a lot of time and confusion.
By combining directory structures, naming conventions, Pester's in-built tagging, and automation scripts, you can efficiently manage and run your Pester tests, ensuring those that need a fresh process get one, while others run as usual.

ATAP uses the directories RegularTests and RequiresNewProcess
ATAP uses the file suffix  _NewProcess for any individual test file that requires a new process
ATAP uses the tags Regular and NewProcess in the -Tag parameter in the Describe block of Pester tests
ATAP implements version tracking of the .DLL(s) used in test runs, and runs either the Regular or NewProcess tests as necessary.
ATAP runs the tests that need a new process via the Pester's -RunInNewProcess parameter

