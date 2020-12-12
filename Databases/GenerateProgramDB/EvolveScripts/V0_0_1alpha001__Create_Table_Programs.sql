SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Programs](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ProgramName] [varchar](max) NOT NULL,
	[sourceRelativePath] [varchar](255) NOT NULL,
	[testRelativePath] [varchar](255) NOT NULL,
	[subDirectoryForGeneratedFiles] [varchar](255) NOT NULL,
	[baseNamespaceName] [varchar](max) NOT NULL,
	[isService] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
