-- =====================================================================
-- V00.01.000301__Create_User_Stored_Procedures.sql
--
-- DEPRECATED: usp_HashPassword (SHA-512 + CRYPT_GEN_RANDOM salt) was
-- superseded by Argon2id password hashing in the .NET application layer
-- (AceCommander/Services/PasswordHasher.cs).
--
-- SQL Server cannot run Argon2id (memory-hard, NIST-recommended PHC).
-- All password hashing and verification is performed exclusively in .NET
-- using the Konscious.Security.Cryptography.Argon2 NuGet package.
--
-- The [User].HashAlgorithm column default is N'Argon2id'.
-- The [User].SaltedAndHashedPassword column stores the PHC string:
--   $argon2id$v=19$m=65536,t=3,p=4$<base64_salt>$<base64_hash>
--
-- This migration is intentionally empty (no SQL objects created).
-- =====================================================================
USE ATAPUtilities;
GO
