# ATAP.Utilities package graph tests

This isolated xUnit project exercises security-sensitive package behavior without depending
on the broader persistence test fixture or a live SQL Server.

- `SqlServerDataProvider_CreatesMicrosoftDataConnectionWithoutOpeningIt` verifies that the
  selected ServiceStack SQL Server Data provider references and creates
  `Microsoft.Data.SqlClient.SqlConnection`, remains closed, and has no
  `System.Data.SqlClient` assembly reference.
- `SignedXml_SignAndVerify_RoundTripsInMemory` signs and verifies an in-memory XML document.
- `EncryptedXml_EncryptAndDecrypt_RoundTripsInMemory` encrypts and decrypts an in-memory XML
  element with AES-256.

The project intentionally targets `net8.0`, `net9.0`, and `net10.0`. Verification treats its
checked-in lock as immutable input: forced-evaluate locked restore runs before tests. A lock
candidate may only be generated through the explicit candidate workflow, reviewed, and
adopted deliberately. All validation reuses one task-owned external artifacts context.
Package advisory and deprecation reports are point-in-time, network-dependent evidence;
they are not assertions about the entire repository.

Live SQL connection coverage belongs to Task 15.180.r and is explicitly outside this project.
