MERGE dbo.Roles AS target
USING (VALUES (1, N'Admin'), (2, N'User')) AS source (RoleId, Name)
ON target.RoleId = source.RoleId
WHEN NOT MATCHED THEN
  INSERT (RoleId, Name) VALUES (source.RoleId, source.Name);
