if exists (select * from dbo.sysobjects where id = object_id(N'[tbTempSort]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [tbTempSort]
GO

CREATE TABLE [tbTempSort] (
	[ID] [int] IDENTITY (1, 1) NOT NULL ,
	[SortID] [int] DEFAULT (0) ,
	[SortName] [nvarchar] (255) NULL ,
	[SortParentID] [int] DEFAULT (0),
	[SortParentPath] [varchar] (4000) NULL ,
	[SortOrder] [int] DEFAULT (0),
) ON [PRIMARY]
GO