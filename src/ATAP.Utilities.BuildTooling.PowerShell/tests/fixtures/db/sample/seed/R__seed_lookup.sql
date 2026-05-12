MERGE dbo.Roles AS target
USING (VALUES (1, N'Admin'), (2, N'User')) AS source (RoleId, Name)
ON target.RoleId = source.RoleId
WHEN MATCHED THEN
  UPDATE SET Name = source.Name;
