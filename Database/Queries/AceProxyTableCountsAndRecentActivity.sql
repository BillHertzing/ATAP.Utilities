Use [ATAPUtilities]
/* Counts for every table */
SELECT N'Ace.AISupervisorAttempt' AS TableName, COUNT_BIG(*) AS TotalRecords FROM [Ace].[AISupervisorAttempt]
UNION ALL SELECT N'Ace.AISupervisorExchange', COUNT_BIG(*) FROM [Ace].[AISupervisorExchange]
UNION ALL SELECT N'Ace.AISupervisorExchangeTag', COUNT_BIG(*) FROM [Ace].[AISupervisorExchangeTag]
UNION ALL SELECT N'Ace.AISupervisorMetric', COUNT_BIG(*) FROM [Ace].[AISupervisorMetric]
UNION ALL SELECT N'Ace.AISupervisorMetricCatalog', COUNT_BIG(*) FROM [Ace].[AISupervisorMetricCatalog]
UNION ALL SELECT N'Ace.AISupervisorPrompt', COUNT_BIG(*) FROM [Ace].[AISupervisorPrompt]
UNION ALL SELECT N'Ace.AISupervisorUsage', COUNT_BIG(*) FROM [Ace].[AISupervisorUsage]
UNION ALL SELECT N'Ace.GatherContentSubmission', COUNT_BIG(*) FROM [Ace].[GatherContentSubmission]
UNION ALL SELECT N'Ace.GatherContentSubmissionTag', COUNT_BIG(*) FROM [Ace].[GatherContentSubmissionTag]
ORDER BY TableName;

/* Three most recent rows from tables with a datetime column */
SELECT TOP (3) *, COALESCE([CompletedAtUtc], [StartedAtUtc]) AS SortDateTime
FROM [Ace].[AISupervisorAttempt]
ORDER BY COALESCE([CompletedAtUtc], [StartedAtUtc]) DESC;

SELECT TOP (3) *
FROM [Ace].[AISupervisorExchange]
ORDER BY [RecordedAtUtc] DESC;

SELECT TOP (3) *
FROM [Ace].[AISupervisorMetric]
ORDER BY [RecordedAtUtc] DESC;

SELECT TOP (3) *
FROM [Ace].[AISupervisorMetricCatalog]
ORDER BY [RecordedAtUtc] DESC;

SELECT TOP (3) *
FROM [Ace].[AISupervisorPrompt]
ORDER BY [RecordedAtUtc] DESC;

SELECT TOP (3) *
FROM [Ace].[AISupervisorUsage]
ORDER BY [RecordedAtUtc] DESC;

SELECT TOP (3) *
FROM [Ace].[GatherContentSubmission]
ORDER BY [ReceivedAtUtc] DESC;
