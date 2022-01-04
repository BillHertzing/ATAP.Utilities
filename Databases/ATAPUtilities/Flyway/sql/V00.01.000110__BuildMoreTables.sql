    CREATE TABLE dbo.IGArgument(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGArgument PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAssemblyGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAssemblyGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAssemblyGroupBasicConstructorResult(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAssemblyGroupBasicConstructorResult PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAssemblyGroupSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAssemblyGroupSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAssemblyUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAssemblyUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAssemblyUnitSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAssemblyUnitSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAttribute(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAttribute PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGAttributeGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGAttributeGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGBody(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGBody PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGClass(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGClass PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGComment(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGComment PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGCompilationUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGCompilationUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGConstString(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGConstString PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGConstStringGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGConstStringGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGDelegate(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGDelegate PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGDelegateDeclaration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGDelegateDeclaration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGDelegateGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGDelegateGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGEnumeration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGEnumeration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGEnumerationGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGEnumerationGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGEnumerationMember(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGEnumerationMember PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGGenerateCodeSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGGenerateCodeSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGGenerateProgamProgress(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGGenerateProgamProgress PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGGenerateProgramResult(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGGenerateProgramResult PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGGlobalSettingsSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGGlobalSettingsSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGInterface(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGInterface PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGItemGroupInProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGItemGroupInProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGMethod(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGMethod PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGMethodDeclaration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGMethodDeclaration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGMethodGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGMethodGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGNamespace(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGNamespace PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGPatternReplacement(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGPatternReplacement PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGPropertiesUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGPropertiesUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGProperty(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGProperty PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGPropertyGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGPropertyGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGPropertyGroupInProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGPropertyGroupInProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGResourceItem(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGResourceItem PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGResourceUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGResourceUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGSolutionSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGSolutionSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGStateConfiguration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGStateConfiguration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGStaticVariable(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGStaticVariable PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGStaticVariableGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGStaticVariableGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGUsing(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGUsing PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.IGUsingGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_IGUsingGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GArgumentExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GArgumentExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyGroupBasicConstructorResult(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyGroupBasicConstructorResult PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyGroupPopulateInterfaces(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyGroupPopulateInterfaces PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyGroupSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyGroupSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblySingle(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblySingle PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyUnitExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyUnitExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAssemblyUnitSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAssemblyUnitSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAttribute(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAttribute PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAttributeGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAttributeGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GAttributeGroupExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GAttributeGroupExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GBodyExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GBodyExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GClass(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GClass PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GClassExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GClassExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GCompilationUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GCompilationUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GCompilationUnitExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GCompilationUnitExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GConstString(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GConstString PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GConstStringGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GConstStringGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GDelegate(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GDelegate PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GDelegateDeclaration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GDelegateDeclaration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GDelegateGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GDelegateGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GEnumeration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GEnumeration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GEnumerationMember(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GEnumerationMember PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GEnumerationMemberExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GEnumerationMemberExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GEumerationGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GEumerationGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GGenerateCodeProgressReport(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GGenerateCodeProgressReport PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GGenerateCodeSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GGenerateCodeSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GGenerateProgramResult(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GGenerateProgramResult PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GGlobalSettingsSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GGlobalSettingsSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GInterface(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GInterface PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GInterfaceExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GInterfaceExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GItemGroupInProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GItemGroupInProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GItemGroupInProjectUnitExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GItemGroupInProjectUnitExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GMethod(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GMethod PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GMethodDeclaration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GMethodDeclaration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GMethodExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GMethodExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GMethodGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GMethodGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GMethodGroupExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GMethodGroupExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GNamespace(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GNamespace PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GNamespaceExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GNamespaceExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GProperty(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GProperty PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GPropertyGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GPropertyGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GPropertyGroupExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GPropertyGroupExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GPropertyGroupInProjectUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GPropertyGroupInProjectUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GPropertyGroupInProjectUnitExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GPropertyGroupInProjectUnitExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GResourceItem(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GResourceItem PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GResourceUnit(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GResourceUnit PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GSolutionSignil(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GSolutionSignil PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStateConfiguration(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStateConfiguration PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStatementList(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStatementList PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStatementListExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStatementListExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStaticVariable(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStaticVariable PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStaticVariableBody(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStaticVariableBody PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GStaticVariableGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GStaticVariableGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GUsing(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GUsing PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GUsingGroup(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GUsingGroup PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

    CREATE TABLE dbo.GUsingGroupExtensions(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_GUsingGroupExtensions PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

