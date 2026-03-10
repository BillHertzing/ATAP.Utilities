USE FileSystemAsGraphDB
GO
CREATE TABLE FileInfo
(
	FileName varchar(255),
	Hash varchar(32)
    -- Unique index on $node_id is required.
    -- If no user-defined index is specified, a default index is created.
    INDEX ix_graphid UNIQUE ($node_id)
) AS NODE ON [PRIMARY] --TEXTIMAGE_ON [PRIMARY]
GO

