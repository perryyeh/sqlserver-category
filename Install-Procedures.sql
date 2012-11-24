if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_SELECT]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_SELECT]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_INSERT]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_INSERT]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_DELETE]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_DELETE]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_UPDATE]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_UPDATE]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_MoveSort]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_MoveSort]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_MoveOrder]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_MoveOrder]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[sp_Util_Sort_MoveRevise]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [sp_Util_Sort_MoveRevise]
GO

/*
输出目录树
调用示范:EXEC sp_Util_Sort_SELECT 'SortID,SortName,SortParentID,SortParentPath,SortOrder','tbTempSort',4,1
输入:
	1.字段名(字段名不能为SortNameTree,SortMoveUp,SortMoveDown)
	2.表名
	3.欲调用的分类ID(0或者此ID不存在,即调用所有)
	4.条件(1包含本级ID和所有下级ID,2包含本级ID和子ID,3不包含本级ID的所有下级ID,4不包含本级ID的子ID)
返回:记录集
*/
CREATE PROCEDURE sp_Util_Sort_SELECT
(
	@sField varchar(255),
	@sTable varchar(50),
	@iSortID int,
	@iCond tinyint
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @s nvarchar(4000),@s1 varchar(1000),@s2 varchar(1000)
	SET @s1=CAST(@iSortID AS varchar(10))
	SELECT @sField=(CASE WHEN LEN(@sField)>0 THEN @sField+',' ELSE '' END)

	IF @iSortID>0
		BEGIN
			SET @s='SELECT @s2=SortParentPath FROM '+@sTable+' WHERE SortID='+@s1
			EXEC sp_executesql @s,N'@s2 varchar(4000) OUT',@s2 OUT
			IF @s2 IS Null
				GOTO step1
			ELSE
				GOTO step2
		END
	ELSE
		BEGIN
			GOTO step1
		END

	step1:
		BEGIN
			SELECT @s2=','
			SELECT @s1=(CASE @iCond WHEN 2 THEN ' WHERE SortParentID=0' WHEN 4 THEN ' WHERE SortParentID=0' ELSE '' END)
			GOTO step3
		END

	step2:
		BEGIN
			SELECT @s1=(CASE @iCond WHEN 2 THEN ' WHERE SortID='+@s1+' OR SortParentID='+@s1 WHEN 3 THEN ' WHERE CHARINDEX('','+@s1+','',SortParentPath)>0' WHEN 4 THEN ' WHERE SortParentID='+@s1 ELSE ' WHERE SortID='+@s1+' OR CHARINDEX('','+@s1+','',SortParentPath)>0' END)
			GOTO step3
		END

	step3:
		SET @s='SELECT '+@sField+' dbo.fn_Sort_Tree(SortName,SortParentPath,'''+@s2+''',(SELECT COUNT(0) FROM '+@sTable+' B WHERE B.SortParentID=A.SortParentID AND B.SortOrder>A.SortOrder)) AS SortNameTree,(SELECT COUNT(0) FROM '+@sTable+' B WHERE B.SortParentID=A.SortParentID AND B.SortOrder<A.SortOrder) AS SortMoveUp,(SELECT -COUNT(0) FROM '+@sTable+' B where B.SortParentID=A.SortParentID AND B.SortOrder>A.SortOrder) AS SortMoveDown FROM '+@sTable+' A '+@s1+' ORDER BY SortOrder ASC'
		EXEC (@s)

END
GO

/*
添加分类
调用示范:EXEC sp_Util_Sort_INSERT 'tbTempSort',0,'一级分类2'
输入:
	1.表名
	2.父级ID(为0则添加为一级分类)
	3.分类名
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_INSERT
(
	@sTable varchar(50),
	@iSortParentID int OUTPUT,
	@sSortName nvarchar(255)
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @iSortNum int,@iSortID int,@iSortOrder int,@iChildNum int
	DECLARE @upt_error int,@ins_error int
	DECLARE @sSortParentPath varchar(4000),@s nvarchar(4000),@sSortParentID varchar(10)

	SET @sSortParentID=CAST(@iSortParentID AS varchar(10))

	IF @iSortParentID>0
		BEGIN
			SET @s='SELECT @sSortParentPath=SortParentPath,@iSortOrder=SortOrder FROM '+@sTable+' WHERE SortID='+@sSortParentID
			EXEC sp_executesql @s,N'@sSortParentPath varchar(4000) OUT,@iSortOrder int OUT',@sSortParentPath OUT,@iSortOrder OUT

			IF (@iSortOrder IS NULL) OR (@sSortParentPath IS NULL)
				BEGIN
					SET @iSortParentID=-111101
					GOTO step3
				END
			ELSE
				BEGIN
					SET @sSortParentPath=@sSortParentPath+@sSortParentID+','
					GOTO step1
				END
		END
	ELSE
		BEGIN
			SELECT @iSortParentID=0, @sSortParentPath=',', @iSortOrder=0
			GOTO step1
		END

	step1:
		BEGIN
			SET @s='SELECT @iSortID=ISNULL(MAX(SortID),0)+1 FROM '+@sTable
			EXEC sp_executesql @s,N'@iSortID int OUT',@iSortID OUT
			GOTO step2
		END

	step2:
		BEGIN
			SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+1 WHERE SortOrder>'+CAST(@iSortOrder AS varchar(10))
			EXEC (@s)
			SELECT @upt_error=@@ERROR
			
			SET @iSortOrder=@iSortOrder+1

			SET @s='INSERT INTO '+@sTable+' (SortID,SortName,SortParentID,SortParentPath,SortOrder) VALUES ('+CAST(@iSortID AS varchar(10))+','''+@sSortName+''','+@sSortParentID+','''+@sSortParentPath+''','+CAST(@iSortOrder AS varchar(10))+')'
			EXEC (@s)
			SELECT @ins_error=@@ERROR

			SELECT @iSortParentID=(CASE WHEN (@upt_error=0 AND @ins_error=0) THEN 111151 ELSE -111100 END)
			GOTO step3
		END

	step3:
		RETURN(@iSortParentID)

END
GO

/*
删除分类
调用示范:EXEC sp_Util_Sort_DELETE 'tbTempSort',2
输入:
	1.表名
	2分类ID(如果ID不存在,则报错)
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_DELETE
(
	@sTable varchar(50),
	@iSortID int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @i int
	DECLARE @del_error int,@upt_error int
	DECLARE @s nvarchar(4000)

	SET @s='SELECT @i=SortOrder FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))
	EXEC sp_executesql @s,N'@i int OUT',@i OUT
	IF @i Is Null
		SET @iSortID=-111102
	ELSE
		BEGIN
			DECLARE @i2 int
			SET @s='SELECT @i2=MAX(SortOrder) FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
			EXEC sp_executesql @s,N'@i2 int OUT',@i2 OUT
			SET @i2=@i2-@i+1

			SET @s='DELETE FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
			EXEC (@s)
			SELECT @del_error=@@ERROR

			SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST(@i2 AS varchar(10))+' WHERE SortOrder>'+CAST(@i AS varchar(10))
			EXEC (@s)
			SELECT @upt_error=@@ERROR

			SELECT @iSortID=(CASE WHEN (@del_error=0 AND @upt_error=0) THEN 111153 ELSE -111100 END)
		END

	RETURN(@iSortID)
END
GO

/*
更新分类名称
调用示范:EXEC sp_Util_Sort_UPDATE 'tbTempSort',1,'一级分类'
输入:
	1.表名
	2.分类ID(如果ID不存在,则报错)
	3.分类名称
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_UPDATE
(
	@sTable varchar(50),
	@iSortID int OUTPUT,
	@sSortName nvarchar (255)
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @i int
	DECLARE @upt_error int
	DECLARE @s nvarchar(4000)

	SET @s='SELECT @i=COUNT(0) FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))
	EXEC sp_executesql @s,N'@i int OUT',@i OUT
	
	IF @i>0
		BEGIN
			SET @s='UPDATE '+@sTable+' SET SortName='''+@sSortName+''' WHERE SortID='+CAST(@iSortID AS varchar(10))
			EXEC (@s)
			SELECT @upt_error=@@ERROR
			SELECT @iSortID=(CASE @upt_error WHEN 0 THEN 111152 ELSE -111100 END)
		END
	ELSE
		BEGIN
			SELECT @iSortID=-111102
		END

	RETURN(@iSortID)
END
GO

/*
更新分类排序
调用示范:EXEC sp_Util_Sort_MoveOrder 'tbTempSort',7,1
输入:
	1.表名
	2.分类ID(如果ID不存在,则报错)
	3.上下调动的级别
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_MoveOrder
(
	@sTable varchar(50),
	@iSortID int OUTPUT,
	@iSortOrder int
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @i1 int,@i2 int
	DECLARE @upt_error1 int,@upt_error2 int
	DECLARE @s nvarchar(4000)

	SET @s='SELECT @i1=SortParentID,@i2=SortOrder FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))
	EXEC sp_executesql @s,N'@i1 int OUT,@i2 int OUT',@i1 OUT,@i2 OUT
	IF (@i1 IS NOT NULL) AND (@i2 IS NOT NULL)
		BEGIN
			DECLARE @i3 int,@i4 int,@i5 int,@i6 int
			SET @s='SELECT @i3=COUNT(0) FROM '+@sTable+' WHERE SortParentID='+CAST(@i1 AS varchar(10))+' AND SortOrder<'+CAST(@i2 AS varchar(10))--能上移的个数
			EXEC sp_executesql @s,N'@i3 int OUT',@i3 OUT

			SET @s='SELECT @i4=-COUNT(0) FROM '+@sTable+' WHERE SortParentID='+CAST(@i1 AS varchar(10))+' AND SortOrder>'+CAST(@i2 AS varchar(10))--能下移的个数
			EXEC sp_executesql @s,N'@i4 int OUT',@i4 OUT

			SET @s='SELECT @i5=MAX(SortOrder) FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'--本级以及本级子类中最大的SortOrder
			EXEC sp_executesql @s,N'@i5 int OUT',@i5 OUT

			SELECT @iSortOrder=(CASE WHEN @iSortOrder>@i3 THEN @i3 WHEN @iSortOrder<@i4 THEN @i4 ELSE @iSortOrder END)

			IF @iSortOrder>0 --上移
				BEGIN
					SET @s='SELECT IDENTITY(int,1,1) AS ID_Num,SortOrder INTO #tmpSort1 FROM '+@sTable+' WHERE SortParentID='+CAST(@i1 AS varchar(10))+' AND SortOrder<'+CAST(@i2 AS varchar(10))+' ORDER BY SortOrder DESC;SELECT @i6=SortOrder From #tmpSort1 where ID_Num='+CAST(@iSortOrder AS varchar(10))+';DROP TABLE #tmpSort1'--同级之上的分类倒序排列,取得需要位置的排序Order
					EXEC sp_executesql @s,N'@i6 int OUT',@i6 OUT

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST((@i5-@i2+1) AS varchar(10))+' WHERE SortOrder>'+CAST((@i6-1) AS varchar(10))+' AND SortOrder<'+CAST(@i2 AS varchar(10))
					EXEC (@s)
					SELECT @upt_error1=@@ERROR

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST((@i2-@i6) AS varchar(10))+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
					EXEC (@s)
					SELECT @upt_error2=@@ERROR

					SELECT @iSortID=(CASE WHEN (@upt_error1=0 AND @upt_error2=0) THEN 111154 ELSE -111100 END)
				END
			ELSE IF @iSortOrder<0 --下移
				BEGIN
					SET @iSortOrder=ABS(@iSortOrder)

					SET @s='SELECT IDENTITY(int, 1,1) AS ID_Num,SortID INTO #tmpSort2 FROM '+@sTable+' WHERE SortParentID='+CAST(@i1 AS varchar(10))+' AND SortOrder>'+CAST(@i2 AS varchar(10))+' ORDER BY SortOrder ASC;SELECT @i6=SortID From #tmpSort2 where ID_Num='+CAST(@iSortOrder AS varchar(10))+';DROP TABLE #tmpSort2'--同级之下的分类顺序排列,取得需要位置的SortID
					EXEC sp_executesql @s,N'@i6 int OUT',@i6 OUT

					SET @s='SELECT @i6=MAX(SortOrder) From '+@sTable+' WHERE SortID='+CAST(@i6 AS varchar(10))+' OR CHARINDEX('','+CAST(@i6 AS varchar(10))+','',SortParentPath)>0'--移动后的级下的最后一个id的排序值
					EXEC sp_executesql @s,N'@i6 int OUT',@i6 OUT

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST((@i5-@i2+1) AS varchar(10))+' WHERE SortOrder<'+CAST((@i6+1) AS varchar(10))+' AND SortOrder>'+CAST(@i5 AS varchar(10))
					EXEC (@s)
					SELECT @upt_error1=@@ERROR

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST((@i6-@i5) AS varchar(10))+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
					EXEC (@s)
					SELECT @upt_error2=@@ERROR

					SELECT @iSortID=(CASE WHEN (@upt_error1=0 AND @upt_error2=0) THEN 111154 ELSE -111100 END)
				END
			ELSE --报错
				BEGIN
					SET @iSortID=-111103
				END
		END
	ELSE --报错
		BEGIN
			SET @iSortID=-111102
		END

RETURN(@iSortID)
END
GO

/*
更新分类父级
调用示范:EXEC sp_Util_Sort_MoveSort 'tbTempSort',7,1
输入:
	1.表名
	2.分类ID(如果ID不存在,则报错)
	3.要调到的父级ID(此ID不能为自己的子类)
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_MoveSort
(
	@sTable varchar(50),
	@iSortID int OUTPUT,
	@iSortParent int
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @i1 int,@i2 int,@i3 int
	DECLARE @upt_error1 int,@upt_error2 int,@upt_error3 int
	DECLARE @s1 varchar(4000),@s2 varchar(4000),@s3 varchar(4000),@s nvarchar(4000)

	SET @s='SELECT @i1=SortOrder,@i2=SortParentID,@s1=SortParentPath FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))
	EXEC sp_executesql @s,N'@i1 int OUT,@i2 int OUT,@s1 varchar(4000) OUT',@i1 OUT,@i2 OUT,@s1 OUT

	IF @iSortParent>0
		BEGIN
			SET @s='SELECT @s2=SortParentPath,@i3=SortOrder FROM '+@sTable+' WHERE SortID='+CAST(@iSortParent AS varchar(10))
			EXEC sp_executesql @s,N'@s2 varchar(4000) OUT,@i3 int OUT',@s2 OUT,@i3 OUT

			SELECT @s3=(CASE WHEN (@s2 IS NOT NULL) THEN @s2+CAST(@iSortParent AS varchar(10))+',' ELSE ',' END)
		END
	ELSE --如果欲移到的id<1,则提升为一级分类
		BEGIN
			SELECT @s2=',',@i3=0,@s3=','
		END

	IF @i1=Null
		SET @iSortID=-111102
	ELSE IF @s2=Null
		SET @iSortID=-111104
	ELSE IF (@s2 IS NOT NULL) AND CHARINDEX(','+CAST(@iSortID AS varchar(10))+',',@s2)>0
		SET @iSortID=-111105
	ELSE IF @i2=@iSortParent
		SET @iSortID=-111106
	ELSE
		BEGIN
			DECLARE @i4 int,@i5 int
			SET @s='SELECT @i4=MAX(SortOrder) FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'--本级以及下级分类最大排序
			EXEC sp_executesql @s,N'@i4 int OUT',@i4 OUT
			SET @i4=@i4-@i1+1 --需要移动的个数

			IF @i1>@i3--父级在己之上
				BEGIN
					SET @i5=@i1-@i3-1 --中间的需要移动的个数

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST(@i4 AS varchar(10))+' WHERE SortOrder>'+CAST(@i3 AS varchar(10))+' AND SortOrder<'+CAST(@i1 AS varchar(10))
					EXEC (@s)
					SELECT @upt_error1=@@ERROR

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST(@i5 AS varchar(10))+',SortParentID='+CAST(@iSortParent AS varchar(10))+',SortParentPath='''+@s3+''' WHERE SortID='+CAST(@iSortID AS varchar(10))
					EXEC (@s)
					SELECT @upt_error2=@@ERROR

					IF @i2=0
						SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST(@i5 AS varchar(10))+',SortParentPath=LEFT('''+@s3+''',LEN('''+@s3+''')-1)+SortParentPath WHERE CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
					ELSE
						BEGIN
							SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST(@i5 AS varchar(10))+',SortParentPath=REPLACE(SortParentPath,'''+@s1+''','''+@s3+''') WHERE CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
						END
					EXEC (@s)
					SELECT @upt_error3=@@ERROR
				END
			ELSE
				BEGIN
					SET @s='SELECT @i1=MAX(SortOrder) FROM '+@sTable+' WHERE SortID='+CAST(@iSortID AS varchar(10))+' OR CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'--本类的最大排序order
					EXEC sp_executesql @s,N'@i1 int OUT',@i1 OUT

					SET @i5=@i3-@i1 --中间的需要移动的个数

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder-'+CAST(@i4 AS varchar(10))+' WHERE SortOrder<'+CAST((@i3+1) AS varchar(10))+' AND SortOrder>'+CAST(@i1 AS varchar(10))
					EXEC (@s)
					SELECT @upt_error1=@@ERROR

					SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST(@i5 AS varchar(10))+',SortParentID='+CAST(@iSortParent AS varchar(10))+',SortParentPath='''+@s3+''' WHERE SortID='+CAST(@iSortID AS varchar(10))
					EXEC (@s)
					SELECT @upt_error2=@@ERROR

					IF @i2=0
						SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST(@i5 AS varchar(10))+',SortParentPath=LEFT('''+@s3+''',LEN('''+@s3+''')-1)+SortParentPath WHERE CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
					ELSE
						BEGIN
							SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+'+CAST(@i5 AS varchar(10))+',SortParentPath=REPLACE(SortParentPath,'''+@s1+''','''+@s3+''') WHERE CHARINDEX('','+CAST(@iSortID AS varchar(10))+','',SortParentPath)>0'
						END
					EXEC (@s)
					SELECT @upt_error3=@@ERROR
				END

				SELECT @iSortID=(CASE WHEN (@upt_error1=0 AND @upt_error2=0) THEN 111155 ELSE -111100 END)
		END

	RETURN(@iSortID)
END
GO


/*
修正分类
调用示范:EXEC sp_Util_Sort_MoveRevise 'tbTempSort',0
输入:
	1.表名
	2.返回值
返回:正值表示操作成功,负值表示操作失败,具体见返回代码
*/
CREATE PROCEDURE sp_Util_Sort_MoveRevise
(
	@sTable varchar(50),
	@iSortID int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @x int,@i int,@j int,@i1 int,@i2 int,@i3 int
	DECLARE @s nvarchar(4000),@s1 nvarchar(4000)
	
	SELECT @x=1
	SET @s='SELECT @i=COUNT(0) FROM '+@sTable
	EXEC sp_executesql @s,N'@i int OUT',@i OUT
	IF @i<1
		BEGIN
			SET @iSortID=-111107
			GOTO step1
		END

	SET @s='UPDATE '+@sTable+' SET SortOrder=-1'
	EXEC (@s)

	SET @s='SELECT @i=MAX(dbo.fn_CharStat('','',SortParentPath))+1 FROM '+@sTable
	EXEC sp_executesql @s,N'@i int OUT',@i OUT

	WHILE @x<@i
	BEGIN
		SET @s='SELECT @j=COUNT(0) FROM '+@sTable+'  WHERE SortOrder<0 AND dbo.fn_CharStat('','',SortParentPath)='+CAST(@x AS varchar(10))
		EXEC sp_executesql @s,N'@j int OUT',@j OUT

		WHILE @j>0
		BEGIN
			SET @s='SELECT TOP 1 @i1=SortID,@i2=SortParentID FROM '+@sTable+' WHERE SortOrder<0 AND dbo.fn_CharStat('','',SortParentPath)='+CAST(@x AS varchar(10))
			EXEC sp_executesql @s,N'@i1 int OUT,@i2 int OUT',@i1 OUT,@i2 OUT
			IF @i2=0
				SELECT @i3=0, @s1=',' --父排序Order,父路径
			ELSE
				BEGIN
					SET @s='SELECT TOP 1 @i3=SortOrder,@s1=SortParentPath FROM '+@sTable+' WHERE SortID='+CAST(@i2 AS varchar(10))
					EXEC sp_executesql @s,N'@i3 int OUT,@s1 varchar(4000) OUT',@i3 OUT,@s1 OUT
					IF (@i3 IS NULL) OR (@s1 IS NULL)
						SELECT @i3=0, @s1=',', @i2=0 --父排序Order,父路径,父ID
					ELSE
						BEGIN
							SELECT @s1=@s1+CAST(@i2 AS varchar(10))+',' --父路径
						END
				END

			SET @s='UPDATE '+@sTable+' SET SortOrder=SortOrder+1 WHERE SortOrder>'+CAST(@i3 AS varchar(10))
			EXEC (@s)

			SET @s='UPDATE '+@sTable+' SET SortParentID='+CAST(@i2 AS varchar(10))+',SortParentPath='''+@s1+''',SortOrder='+CAST((@i3+1) AS varchar(10))+' WHERE SortID='+CAST(@i1 AS varchar(10))
			EXEC (@s)
			SET @j=@j-1
		END
		SET @x=@x+1
	END
	SET @iSortID=111156
	GOTO step1

	step1:
		RETURN(@iSortID)
END
GO