SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    c.column_id AS ColumnOrdinal,
    c.name AS ColumnName,
    ty.name AS DataType,
    CASE
        WHEN ty.name IN ('varchar', 'char', 'varbinary', 'binary')
            THEN c.max_length
        WHEN ty.name IN ('nvarchar', 'nchar')
            THEN c.max_length / 2
    END AS MaxLength,
    c.precision AS [Precision],
    c.scale AS [Scale],
    c.is_nullable AS IsNullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE s.name = N'Ace'
  AND t.name IN (
      N'AISupervisorAttempt',
      N'AISupervisorExchange',
      N'AISupervisorExchangeTag',
      N'AISupervisorMetric',
      N'AISupervisorMetricCatalog',
      N'AISupervisorPrompt',
      N'AISupervisorUsage',
      N'GatherContentSubmission',
      N'GatherContentSubmissionTag'
  )
ORDER BY
    t.name,
    c.column_id;
