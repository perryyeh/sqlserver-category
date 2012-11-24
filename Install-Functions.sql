if exists (select * from dbo.sysobjects where id = object_id(N'[fn_CharStat]') and xtype in (N'FN', N'IF', N'TF'))
drop function [fn_CharStat]
GO
/*
检查一字符在另一字符中个数
*/
CREATE FUNCTION fn_CharStat
(
	@s1 nvarchar(4000),--被检查字符
	@s2 nvarchar(4000) --检查字符
)
RETURNS int
AS
BEGIN
	DECLARE @i int,@i1 int,@i2 int,@i3 int
	DECLARE @s nvarchar(4000)

	SELECT @i1=LEN(@s1),@i2=LEN(@s2)

	IF (@i1>@i2) OR @i1<1
		SET @i=0
	ELSE
		BEGIN
			SET @s=REPLACE(@s2,@s1,'')
			SET @i3=LEN(@s)
			SET @i=(@i2-@i3)/@i1
		END

	RETURN @i
END
GO


if exists (select * from dbo.sysobjects where id = object_id(N'[fn_Sort_Tree]') and xtype in (N'FN', N'IF', N'TF'))
drop function [fn_Sort_Tree]
GO
/*
输出树型目录函数
*/
CREATE FUNCTION fn_Sort_Tree
(
	@SortName nvarchar(255),--分类名
	@SortParentPath varchar(4000),--本分类父路径
	@ParentPath varchar(4000),--上级分类父路径
	@iNext int
)
RETURNS nvarchar(4000)
AS
BEGIN
	DECLARE @s nvarchar(4000)
	DECLARE @i1 int,@i2 int,@i3 int
	SELECT @i1=dbo.fn_CharStat(',',@SortParentPath), @i2=dbo.fn_CharStat(',',@ParentPath)
	SELECT @i3=@i1-@i2, @s=''
	WHILE @i3>0
	BEGIN
		SELECT @i3=@i3-1,@s=@s+'│'
	END

	BEGIN
		IF @iNext>0
			SET @s=@s+'├'+@SortName
		ELSE
			SET @s=@s+'└'+@SortName
	END

	RETURN @s
END
GO