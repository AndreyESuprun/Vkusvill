USE [master]
GO
/****** Object:  Database [VkusVill]    Script Date: 14.02.2020 0:28:51 ******/
IF  EXISTS (SELECT name FROM sys.databases WHERE name = N'VkusVill')
DROP DATABASE [VkusVill]
GO
/****** Object:  Database [VkusVill]    Script Date: 14.02.2020 0:28:51 ******/
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'VkusVill')
BEGIN
CREATE DATABASE [VkusVill]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'VkusVill', FILENAME = N'C:\SQL.DATA\VkusVill.mdf' , SIZE = 4160KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'VkusVill_log', FILENAME = N'C:\SQL.LOG\VkusVill_log.ldf' , SIZE = 1040KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
END

GO
ALTER DATABASE [VkusVill] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [VkusVill].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [VkusVill] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [VkusVill] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [VkusVill] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [VkusVill] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [VkusVill] SET ARITHABORT OFF 
GO
ALTER DATABASE [VkusVill] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [VkusVill] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [VkusVill] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [VkusVill] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [VkusVill] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [VkusVill] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [VkusVill] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [VkusVill] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [VkusVill] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [VkusVill] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [VkusVill] SET  ENABLE_BROKER 
GO
ALTER DATABASE [VkusVill] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [VkusVill] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [VkusVill] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [VkusVill] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [VkusVill] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [VkusVill] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [VkusVill] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [VkusVill] SET RECOVERY FULL 
GO
ALTER DATABASE [VkusVill] SET  MULTI_USER 
GO
ALTER DATABASE [VkusVill] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [VkusVill] SET DB_CHAINING OFF 
GO
ALTER DATABASE [VkusVill] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [VkusVill] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
EXEC sys.sp_db_vardecimal_storage_format N'VkusVill', N'ON'
GO
USE [VkusVill]
GO
/****** Object:  StoredProcedure [dbo].[pCalculateLoad]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[pCalculateLoad]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'/*	предположительный алгоритм
	-- получение остатка при наличии готовой величины либо рассчет к началу периода отгрузки - в штуках
	-- суммирование прогноза продаж за весь период - в штуках
	-- получение необходимой разницы товара для отгрузки - в коробках
	
*/

create procedure [dbo].[pCalculateLoad]
	
	@FirstDay date, -- первый день периода для рассчета отгрузки
	@DayCount int, -- число дней в периоде для рассчета отгрузки
	@ProductID int = null,
	@BranchID int = null
	
as
begin

	
	begin tran
	begin try

		delete from LoadPlan 
		where 
			LoadPlanDate = @FirstDay 
			and (ProductID = @ProductID or @ProductID is null)
			and (BranchID = @BranchID or @BranchID is null);

		insert into LoadPlan (LoadPlanDate, BranchID, ProductID, BoxTypeID, LoadPlanBoxCount)
  
		select 
			@FirstDay, 
			rt.BranchID,
			rt.ProductID,
			rt.BoxTypeID,
			rt.BoxToLoad
		from 
		(
			select 
				r.BranchID, r.ProductID, r.RemainDate, box.BoxTypeID,
				sum(r.RemainCount) as RemainCount, -- RemainCount - остаток на окончание указанных суток 
				isnull(sum(clcsls.SaleCount), 0) as UnaccountedSales, -- UnaccountedSales - неподсчитанные остатки
				sum(clcprd.SumPlanCount) as SumPlanCount, -- запланировано продаж
				sum(clcprd.SumPlanCount) 
					- sum(r.RemainCount) 
					+ isnull(sum(clcsls.SaleCount), 0)  
						as CountToLoad,					-- штучки к отгрузке
				dbo.fHowManyBoxes(sum(clcprd.SumPlanCount) 
					- sum(r.RemainCount) 
					+ isnull(sum(clcsls.SaleCount), 0) , box.CountOfUnits) as BoxToLoad	-- коробков к отгрузке
		
			from 
				(   
					select
						BranchID, ProductID, RemainDate, RemainCount, 
						ROW_NUMBER() over (partition by BranchID, ProductID order by RemainDate desc) RN
					from Remain 
					where (ProductID = @ProductID or @ProductID is null) and (BranchID = @BranchID or @BranchID is null)
						and  RemainDate < @FirstDay
				) as r	-- выбираем готовые остатки

				left join 
				(
					select BranchID, ProductID, SaleDate, SaleCount
					from vwSalesSummary
				) as clcsls	 -- в случае необходимости досчитываем остатки до начала отгрузки
						on clcsls.BranchID = r.BranchID and clcsls.ProductID = r.ProductID 
						and clcsls.SaleDate > r.RemainDate and SaleDate < @FirstDay
		 
				inner join
				(
					select BranchID, ProductID, sum(SalePlanCount) SumPlanCount
					from SalesPlan
					where SalePlanDate >= @FirstDay and SalePlanDate < DATEADD(DAY, @DayCount, @FirstDay) 
					group by BranchID, ProductID
				) as clcprd -- выбираем прогноз
					on clcprd.ProductID = r.ProductID and clcprd.BranchID = r.BranchID

				inner join
				(
					select ProductID, b.CountOfUnits, b.BoxTypeID
					from Product p
						inner join BoxType b on b.BoxTypeID = p.BoxTypeID
				) as box -- выбираем коробочки
					on box.ProductID = r.ProductID

			where r.RN = 1
			group by r.BranchID, r.ProductID, r.RemainDate, box.CountOfUnits, box.BoxTypeID
		) rt
		where rt.BoxToLoad > 0

	end try
	begin catch
		
		if @@TRANCOUNT > 0 rollback tran

	end catch

	commit tran;
	
	return 1;
end;
' 
END
GO
/****** Object:  StoredProcedure [dbo].[pCalculatePlan]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[pCalculatePlan]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'/*

процедура генерации прогноза продаж 
на одну неделю по дням
на основании данных предыдущих недель
в зависимости от дня недели,
прогноз записывается в таблицу SalesPlan

прогноз строится либо на основе среднего значения для рассматриваемого дня недели из предыдущих периодов,
либо, если обнаружены сохраняющийся рост (или убывание) от недели к неделе, то искомый прогноз будет 
выведен, согласно этой тенденции, изменяясь на усредненную дельту прироста (или убывания)

*/
create procedure [dbo].[pCalculatePlan]
	
	@FirstPlanDay date, -- дата, с которой нужно спрогнозировать продажи
	@ProductID int = null,
	@BranchID int = null
	
as
begin
	
	begin try
	begin tran
		
		delete from SalesPlan
		where 
			SalePlanDate in 
				(select d from dbo.fGetPlanningWeek(@FirstPlanDay)) 
			and (ProductID = @ProductID or @ProductID is null)
			and (BranchID = @BranchID or @BranchID is null)

		insert into SalesPlan ( DW,  ProductID, BranchID, SalePlanDate, SalePlanCount)
		select [DayOfWeek], ProductID, BranchID, [Date], PredictCount 
		from 
		(
			select 
				ft.[Date],
				ft.[DayOfWeek],
				ft.BranchID,
				ft.ProductID,
				ft.PredictCount,
				ft.IsTrend,
				count(*) over (partition by ft.[Date], ft.[DayOfWeek], ft.BranchID, ft.ProductID order by IsTrend desc) as Variant
			from
			(	select 
				distinct
					placal.d as [Date]
					,tp.DW as [DayOfWeek]
					,tp.BranchID
					,tp.ProductID
					,tp.IsTrend
					,case IsTrend when 1 then tp.LastValue + tp.AvgDelta else tp.AvgDWCount end  as PredictCount
		
				from 
				(
					select 
						v.DW,
						v.BranchID,
						v.ProductID,
						v.AvgDWCount,
						case when v.CntSameDeltaSign = v.CntInGroup - 1 then 1 else 0 end as IsTrend,
						avg(v.Delta) over (partition by ProductID, DW, BranchID) AvgDelta,
						FIRST_VALUE(SaleCount) over (partition by ProductID, DW, BranchID order by SaleDate desc) LastValue
	
					from vwSalesSummary v
					where v.SaleCount <> 0 
						and (ProductID = @ProductID or @ProductID is null)
						and (BranchID = @BranchID or @BranchID is null)


				) as tp 
					inner join 
					(
						select d, dw from dbo.fGetPlanningWeek(@FirstPlanDay)
					) as placal  on placal.DW = tp.DW
			) as ft
		) as t
		where Variant = 1


	end try

	begin catch 
		if @@TRANCOUNT > 0 rollback tran
	end catch

	commit tran;

	return 1;
end;
' 
END
GO
/****** Object:  UserDefinedFunction [dbo].[fHowManyBoxes]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fHowManyBoxes]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'create function [dbo].[fHowManyBoxes](@NeccesaryCount int, @BoxCapacity int)
	returns int	
as
begin
	return 
		(select 
			case	when @NeccesaryCount/@BoxCapacity * @BoxCapacity < @NeccesaryCount 
						then @NeccesaryCount/@BoxCapacity + 1 
					when @NeccesaryCount < 0 then 0
					else @NeccesaryCount/@BoxCapacity 
			end)

end
' 
END

GO
/****** Object:  Table [dbo].[BoxType]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BoxType]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[BoxType](
	[BoxTypeID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[CountOfUnits] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[BoxTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Branch]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Branch]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Branch](
	[BranchID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[BranchAddress] [varchar](128) NULL,
PRIMARY KEY CLUSTERED 
(
	[BranchID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LoadPlan]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LoadPlan]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LoadPlan](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[LoadPlanDate] [date] NULL,
	[BranchID] [int] NULL,
	[ProductID] [int] NULL,
	[BoxTypeID] [int] NULL,
	[LoadPlanBoxCount] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
/****** Object:  Table [dbo].[Product]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Product]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Product](
	[ProductID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[BoxTypeID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Remain]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Remain]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Remain](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[BranchID] [int] NULL,
	[ProductID] [int] NULL,
	[RemainDate] [date] NULL,
	[RemainCount] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
/****** Object:  Table [dbo].[Sale]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Sale]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Sale](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DW] [int] NULL,
	[ProductID] [int] NULL,
	[BranchID] [int] NULL,
	[SaleDate] [date] NULL,
	[SaleCount] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
/****** Object:  Table [dbo].[SalesPlan]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SalesPlan]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SalesPlan](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[SalePlanDate] [date] NULL,
	[DW] [int] NULL,
	[BranchID] [int] NULL,
	[ProductID] [int] NULL,
	[SalePlanCount] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
/****** Object:  View [dbo].[vwSalesSummary]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vwSalesSummary]'))
EXEC dbo.sp_executesql @statement = N'
create view [dbo].[vwSalesSummary]
as 
	
select 
	t.DW,
	t.BranchID,
	t.ProductID,
	t.SaleDate,
	t.SaleCount,
	t.AvgDWCount,
	t.MinDWCount,
	t.MaxDWCount,
	t.Lead,
	t.Delta,
	count(*) over (partition by ProductID, DW, BranchID) CntInGroup
	, 

		sum(case when Delta > 0 then 1 else 0 end) over (partition by ProductID, DW, BranchID order by SaleDate)
		- sum(case when Delta < 0 then 1 else 0 end) over (partition by ProductID, DW, BranchID order by SaleDate)
			as CntSameDeltaSign -- промежуточная величина - количество ячеек с одинаковым знаком, для определения тренда
from 
(
	select  s.*

		, avg(SaleCount) over (partition by ProductID, DW, BranchID) as AvgDWCount
		, min(SaleCount) over (partition by ProductID, DW, BranchID) as MinDWCount
		, max(SaleCount) over (partition by ProductID, DW, BranchID) as MaxDWCount
		, lead(SaleCount) over (partition by ProductID, DW, BranchID order by SaleDate) as Lead
		, SaleCount - lag(SaleCount) over (partition by ProductID, DW, BranchID order by SaleDate)  as Delta

	
	from Sale s 
	where 
		SaleCount <> 0
	
) as t
' 
GO
/****** Object:  View [dbo].[vwPredict]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vwPredict]'))
EXEC dbo.sp_executesql @statement = N'
create view [dbo].[vwPredict]
as 
select 
distinct
	tp.DW
	,tp.BranchID
	,tp.ProductID
	,case IsTrend when 1 then LastValue + AvgDelta else AvgDWCount end  as PredictCount
from 
(
	select v.*,
		case when v.CntSameDeltaSign = v.CntInGroup - 1 then 1 else 0 end as IsTrend,
		avg(v.Delta) over (partition by ProductID, DW, BranchID) AvgDelta,
		FIRST_VALUE(SaleCount) over (partition by ProductID, DW, BranchID order by SaleDate desc) LastValue
	
	from vwSalesSummary v
	where v.SaleCount <> 0

) as tp' 
GO
/****** Object:  UserDefinedFunction [dbo].[fGetPlanningWeek]    Script Date: 14.02.2020 0:28:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fGetPlanningWeek]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'/*
функция получения недельного набора дат с указанием дней недели, начиная с даты из параметра
*/
create function [dbo].[fGetPlanningWeek](@FirstPlanDay date)
returns table 
as 
	return 
	with cte as (select @FirstPlanDay as d union all 
					select Dateadd(day,1,d) from cte) 
					select top 7 d, DATEPART(DW, d) as dw from cte 
' 
END

GO
SET IDENTITY_INSERT [dbo].[BoxType] ON 

GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (1, N'коробка для всего', 27)
GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (2, N'коробка для печенья', 21)
GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (3, N'лоток яиц 10', 10)
GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (4, N'лоток яиц 30', 30)
GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (5, N'пак минералки', 6)
GO
INSERT [dbo].[BoxType] ([BoxTypeID], [Name], [CountOfUnits]) VALUES (6, N'ящик пиваса', 20)
GO
SET IDENTITY_INSERT [dbo].[BoxType] OFF
GO
SET IDENTITY_INSERT [dbo].[Branch] ON 

GO
INSERT [dbo].[Branch] ([BranchID], [Name], [BranchAddress]) VALUES (1, N'Магаз На Районе', N'Севастополь, ул.Л.Чайкиной, 57')
GO
INSERT [dbo].[Branch] ([BranchID], [Name], [BranchAddress]) VALUES (2, N'Сельский магаз', N'с.Дубки, Ленина, 21')
GO
INSERT [dbo].[Branch] ([BranchID], [Name], [BranchAddress]) VALUES (3, N'Супермаркет в ТЦ', N'Симферополь, Объездная, 201')
GO
SET IDENTITY_INSERT [dbo].[Branch] OFF
GO
SET IDENTITY_INSERT [dbo].[Product] ON 

GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (1, N'Молоко Коровье', 1)
GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (2, N'ПепсиКола', 5)
GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (3, N'Печенье Бельвита', 2)
GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (4, N'Пиво Крым 0.5', 6)
GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (5, N'Яйцо Куриное Окт с1', 3)
GO
INSERT [dbo].[Product] ([ProductID], [Name], [BoxTypeID]) VALUES (6, N'Яйцо Куруное Кра с2', 4)
GO
SET IDENTITY_INSERT [dbo].[Product] OFF
GO
SET IDENTITY_INSERT [dbo].[Remain] ON 

GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (1, 1, 1, CAST(0xB3400B00 AS Date), 2)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (2, 1, 2, CAST(0xB3400B00 AS Date), 4)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (3, 1, 3, CAST(0xB3400B00 AS Date), 50)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (4, 1, 4, CAST(0xB3400B00 AS Date), 30)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (5, 1, 5, CAST(0xB3400B00 AS Date), 60)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (6, 1, 6, CAST(0xB3400B00 AS Date), 60)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (7, 2, 1, CAST(0xB3400B00 AS Date), 1)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (8, 2, 2, CAST(0xB3400B00 AS Date), 2)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (9, 2, 3, CAST(0xB3400B00 AS Date), 25)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (10, 2, 4, CAST(0xB3400B00 AS Date), 20)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (11, 2, 5, CAST(0xB3400B00 AS Date), 30)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (12, 2, 6, CAST(0xB3400B00 AS Date), 30)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (13, 3, 1, CAST(0xB3400B00 AS Date), 10)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (15, 3, 3, CAST(0xB3400B00 AS Date), 125)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (16, 3, 4, CAST(0xB3400B00 AS Date), 200)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (17, 3, 5, CAST(0xB3400B00 AS Date), 500)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (18, 3, 6, CAST(0xB2400B00 AS Date), 300)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (19, 3, 6, CAST(0xB3400B00 AS Date), 180)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (20, 3, 6, CAST(0xB1400B00 AS Date), 88)
GO
INSERT [dbo].[Remain] ([ID], [BranchID], [ProductID], [RemainDate], [RemainCount]) VALUES (21, 3, 2, CAST(0xB3400B00 AS Date), 70)
GO
SET IDENTITY_INSERT [dbo].[Remain] OFF
GO
SET IDENTITY_INSERT [dbo].[Sale] ON 

GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (1, 2, 1, 1, CAST(0xA3400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (2, 2, 2, 1, CAST(0xA3400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (3, 2, 3, 1, CAST(0xA3400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (4, 2, 4, 1, CAST(0xA3400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (5, 2, 5, 1, CAST(0xA3400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (6, 2, 6, 1, CAST(0xA3400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (7, 2, 1, 2, CAST(0xA3400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (8, 2, 2, 2, CAST(0xA3400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (9, 2, 3, 2, CAST(0xA3400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (10, 2, 4, 2, CAST(0xA3400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (11, 2, 5, 2, CAST(0xA3400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (12, 2, 6, 2, CAST(0xA3400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (13, 2, 1, 3, CAST(0xA3400B00 AS Date), 74)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (14, 2, 2, 3, CAST(0xA3400B00 AS Date), 34)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (15, 2, 3, 3, CAST(0xA3400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (16, 2, 4, 3, CAST(0xA3400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (17, 2, 5, 3, CAST(0xA3400B00 AS Date), 200)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (18, 2, 6, 3, CAST(0xA3400B00 AS Date), 212)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (19, 3, 6, 3, CAST(0xA4400B00 AS Date), 132)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (20, 3, 5, 3, CAST(0xA4400B00 AS Date), 160)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (21, 3, 4, 3, CAST(0xA4400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (22, 3, 3, 3, CAST(0xA4400B00 AS Date), 27)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (23, 3, 2, 3, CAST(0xA4400B00 AS Date), 27)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (24, 3, 1, 3, CAST(0xA4400B00 AS Date), 78)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (25, 3, 6, 2, CAST(0xA4400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (26, 3, 5, 2, CAST(0xA4400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (27, 3, 4, 2, CAST(0xA4400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (28, 3, 3, 2, CAST(0xA4400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (29, 3, 2, 2, CAST(0xA4400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (30, 3, 1, 2, CAST(0xA4400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (31, 3, 6, 1, CAST(0xA4400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (32, 3, 5, 1, CAST(0xA4400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (33, 3, 4, 1, CAST(0xA4400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (34, 3, 3, 1, CAST(0xA4400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (35, 3, 2, 1, CAST(0xA4400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (36, 3, 1, 1, CAST(0xA4400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (37, 4, 1, 1, CAST(0xA5400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (38, 4, 2, 1, CAST(0xA5400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (39, 4, 3, 1, CAST(0xA5400B00 AS Date), 12)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (40, 4, 4, 1, CAST(0xA5400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (41, 4, 5, 1, CAST(0xA5400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (42, 4, 6, 1, CAST(0xA5400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (43, 4, 1, 2, CAST(0xA5400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (44, 4, 2, 2, CAST(0xA5400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (45, 4, 3, 2, CAST(0xA5400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (46, 4, 4, 2, CAST(0xA5400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (47, 4, 5, 2, CAST(0xA5400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (48, 4, 6, 2, CAST(0xA5400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (49, 4, 1, 3, CAST(0xA5400B00 AS Date), 55)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (50, 4, 2, 3, CAST(0xA5400B00 AS Date), 42)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (51, 4, 3, 3, CAST(0xA5400B00 AS Date), 28)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (52, 4, 4, 3, CAST(0xA5400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (53, 4, 5, 3, CAST(0xA5400B00 AS Date), 170)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (54, 4, 6, 3, CAST(0xA5400B00 AS Date), 110)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (55, 5, 6, 3, CAST(0xA6400B00 AS Date), 81)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (56, 5, 5, 3, CAST(0xA6400B00 AS Date), 145)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (57, 5, 4, 3, CAST(0xA6400B00 AS Date), 70)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (58, 5, 3, 3, CAST(0xA6400B00 AS Date), 21)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (59, 5, 2, 3, CAST(0xA6400B00 AS Date), 41)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (60, 5, 1, 3, CAST(0xA6400B00 AS Date), 66)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (61, 5, 6, 2, CAST(0xA6400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (62, 5, 5, 2, CAST(0xA6400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (63, 5, 4, 2, CAST(0xA6400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (64, 5, 3, 2, CAST(0xA6400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (65, 5, 2, 2, CAST(0xA6400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (66, 5, 1, 2, CAST(0xA6400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (67, 5, 6, 1, CAST(0xA6400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (68, 5, 5, 1, CAST(0xA6400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (69, 5, 4, 1, CAST(0xA6400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (70, 5, 3, 1, CAST(0xA6400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (71, 5, 2, 1, CAST(0xA6400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (72, 5, 1, 1, CAST(0xA6400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (73, 6, 1, 1, CAST(0xA7400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (74, 6, 2, 1, CAST(0xA7400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (75, 6, 3, 1, CAST(0xA7400B00 AS Date), 11)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (76, 6, 4, 1, CAST(0xA7400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (77, 6, 5, 1, CAST(0xA7400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (78, 6, 6, 1, CAST(0xA7400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (79, 6, 1, 2, CAST(0xA7400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (80, 6, 2, 2, CAST(0xA7400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (81, 6, 3, 2, CAST(0xA7400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (82, 6, 4, 2, CAST(0xA7400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (83, 6, 5, 2, CAST(0xA7400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (84, 6, 6, 2, CAST(0xA7400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (85, 6, 1, 3, CAST(0xA7400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (86, 6, 2, 3, CAST(0xA7400B00 AS Date), 71)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (87, 6, 3, 3, CAST(0xA7400B00 AS Date), 19)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (88, 6, 4, 3, CAST(0xA7400B00 AS Date), 100)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (89, 6, 5, 3, CAST(0xA7400B00 AS Date), 300)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (90, 6, 6, 3, CAST(0xA7400B00 AS Date), 66)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (91, 7, 6, 3, CAST(0xA8400B00 AS Date), 300)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (92, 7, 5, 3, CAST(0xA8400B00 AS Date), 110)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (93, 7, 4, 3, CAST(0xA8400B00 AS Date), 85)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (94, 7, 3, 3, CAST(0xA8400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (95, 7, 2, 3, CAST(0xA8400B00 AS Date), 85)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (96, 7, 1, 3, CAST(0xA8400B00 AS Date), 85)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (97, 7, 6, 2, CAST(0xA8400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (98, 7, 5, 2, CAST(0xA8400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (99, 7, 4, 2, CAST(0xA8400B00 AS Date), 12)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (100, 7, 3, 2, CAST(0xA8400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (101, 7, 2, 2, CAST(0xA8400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (102, 7, 1, 2, CAST(0xA8400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (103, 7, 6, 1, CAST(0xA8400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (104, 7, 5, 1, CAST(0xA8400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (105, 7, 4, 1, CAST(0xA8400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (106, 7, 3, 1, CAST(0xA8400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (107, 7, 2, 1, CAST(0xA8400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (108, 7, 1, 1, CAST(0xA8400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (109, 1, 1, 1, CAST(0xA9400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (110, 1, 2, 1, CAST(0xA9400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (111, 1, 3, 1, CAST(0xA9400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (112, 1, 4, 1, CAST(0xA9400B00 AS Date), 12)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (113, 1, 5, 1, CAST(0xA9400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (114, 1, 6, 1, CAST(0xA9400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (115, 1, 1, 2, CAST(0xA9400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (116, 1, 2, 2, CAST(0xA9400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (117, 1, 3, 2, CAST(0xA9400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (118, 1, 4, 2, CAST(0xA9400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (119, 1, 5, 2, CAST(0xA9400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (120, 1, 6, 2, CAST(0xA9400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (121, 1, 1, 3, CAST(0xA9400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (122, 1, 2, 3, CAST(0xA9400B00 AS Date), 44)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (123, 1, 3, 3, CAST(0xA9400B00 AS Date), 14)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (124, 1, 4, 3, CAST(0xA9400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (125, 1, 5, 3, CAST(0xA9400B00 AS Date), 177)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (126, 1, 6, 3, CAST(0xA9400B00 AS Date), 46)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (127, 2, 6, 3, CAST(0xAA400B00 AS Date), 211)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (128, 2, 5, 3, CAST(0xAA400B00 AS Date), 137)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (129, 2, 4, 3, CAST(0xAA400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (130, 2, 3, 3, CAST(0xAA400B00 AS Date), 41)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (131, 2, 2, 3, CAST(0xAA400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (132, 2, 1, 3, CAST(0xAA400B00 AS Date), 60)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (133, 2, 6, 2, CAST(0xAA400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (134, 2, 5, 2, CAST(0xAA400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (135, 2, 4, 2, CAST(0xAA400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (136, 2, 3, 2, CAST(0xAA400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (137, 2, 2, 2, CAST(0xAA400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (138, 2, 1, 2, CAST(0xAA400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (139, 2, 6, 1, CAST(0xAA400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (140, 2, 5, 1, CAST(0xAA400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (141, 2, 4, 1, CAST(0xAA400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (142, 2, 3, 1, CAST(0xAA400B00 AS Date), 14)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (143, 2, 2, 1, CAST(0xAA400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (144, 2, 1, 1, CAST(0xAA400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (145, 3, 1, 1, CAST(0xAB400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (146, 3, 2, 1, CAST(0xAB400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (147, 3, 3, 1, CAST(0xAB400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (148, 3, 4, 1, CAST(0xAB400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (149, 3, 5, 1, CAST(0xAB400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (150, 3, 6, 1, CAST(0xAB400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (151, 3, 1, 2, CAST(0xAB400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (152, 3, 2, 2, CAST(0xAB400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (153, 3, 3, 2, CAST(0xAB400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (154, 3, 4, 2, CAST(0xAB400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (155, 3, 5, 2, CAST(0xAB400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (156, 3, 6, 2, CAST(0xAB400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (157, 3, 1, 3, CAST(0xAB400B00 AS Date), 64)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (158, 3, 2, 3, CAST(0xAB400B00 AS Date), 27)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (159, 3, 3, 3, CAST(0xAB400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (160, 3, 4, 3, CAST(0xAB400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (161, 3, 5, 3, CAST(0xAB400B00 AS Date), 124)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (162, 3, 6, 3, CAST(0xAB400B00 AS Date), 77)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (163, 4, 6, 3, CAST(0xAC400B00 AS Date), 60)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (164, 4, 5, 3, CAST(0xAC400B00 AS Date), 90)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (165, 4, 4, 3, CAST(0xAC400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (166, 4, 3, 3, CAST(0xAC400B00 AS Date), 47)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (167, 4, 2, 3, CAST(0xAC400B00 AS Date), 31)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (168, 4, 1, 3, CAST(0xAC400B00 AS Date), 47)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (169, 4, 6, 2, CAST(0xAC400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (170, 4, 5, 2, CAST(0xAC400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (171, 4, 4, 2, CAST(0xAC400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (172, 4, 3, 2, CAST(0xAC400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (173, 4, 2, 2, CAST(0xAC400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (174, 4, 1, 2, CAST(0xAC400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (175, 4, 6, 1, CAST(0xAC400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (176, 4, 5, 1, CAST(0xAC400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (177, 4, 4, 1, CAST(0xAC400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (178, 4, 3, 1, CAST(0xAC400B00 AS Date), 12)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (179, 4, 2, 1, CAST(0xAC400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (180, 4, 1, 1, CAST(0xAC400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (181, 5, 1, 1, CAST(0xAD400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (182, 5, 2, 1, CAST(0xAD400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (183, 5, 3, 1, CAST(0xAD400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (184, 5, 4, 1, CAST(0xAD400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (185, 5, 5, 1, CAST(0xAD400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (186, 5, 6, 1, CAST(0xAD400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (187, 5, 1, 2, CAST(0xAD400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (188, 5, 2, 2, CAST(0xAD400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (189, 5, 3, 2, CAST(0xAD400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (190, 5, 4, 2, CAST(0xAD400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (191, 5, 5, 2, CAST(0xAD400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (192, 5, 6, 2, CAST(0xAD400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (193, 5, 1, 3, CAST(0xAD400B00 AS Date), 77)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (194, 5, 2, 3, CAST(0xAD400B00 AS Date), 25)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (195, 5, 3, 3, CAST(0xAD400B00 AS Date), 37)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (196, 5, 4, 3, CAST(0xAD400B00 AS Date), 65)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (197, 5, 5, 3, CAST(0xAD400B00 AS Date), 81)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (198, 5, 6, 3, CAST(0xAD400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (199, 6, 6, 3, CAST(0xAE400B00 AS Date), 200)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (200, 6, 5, 3, CAST(0xAE400B00 AS Date), 274)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (201, 6, 4, 3, CAST(0xAE400B00 AS Date), 77)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (202, 6, 3, 3, CAST(0xAE400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (203, 6, 2, 3, CAST(0xAE400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (204, 6, 1, 3, CAST(0xAE400B00 AS Date), 78)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (205, 6, 6, 2, CAST(0xAE400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (206, 6, 5, 2, CAST(0xAE400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (207, 6, 4, 2, CAST(0xAE400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (208, 6, 3, 2, CAST(0xAE400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (209, 6, 2, 2, CAST(0xAE400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (210, 6, 1, 2, CAST(0xAE400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (211, 6, 6, 1, CAST(0xAE400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (212, 6, 5, 1, CAST(0xAE400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (213, 6, 4, 1, CAST(0xAE400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (214, 6, 3, 1, CAST(0xAE400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (215, 6, 2, 1, CAST(0xAE400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (216, 6, 1, 1, CAST(0xAE400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (217, 7, 1, 1, CAST(0xAF400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (218, 7, 2, 1, CAST(0xAF400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (219, 7, 3, 1, CAST(0xAF400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (220, 7, 4, 1, CAST(0xAF400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (221, 7, 5, 1, CAST(0xAF400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (222, 7, 6, 1, CAST(0xAF400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (223, 7, 1, 2, CAST(0xAF400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (224, 7, 2, 2, CAST(0xAF400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (225, 7, 3, 2, CAST(0xAF400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (226, 7, 4, 2, CAST(0xAF400B00 AS Date), 12)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (227, 7, 5, 2, CAST(0xAF400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (228, 7, 6, 2, CAST(0xAF400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (229, 7, 1, 3, CAST(0xAF400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (230, 7, 2, 3, CAST(0xAF400B00 AS Date), 47)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (231, 7, 3, 3, CAST(0xAF400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (232, 7, 4, 3, CAST(0xAF400B00 AS Date), 91)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (233, 7, 5, 3, CAST(0xAF400B00 AS Date), 180)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (234, 7, 6, 3, CAST(0xAF400B00 AS Date), 338)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (235, 1, 6, 3, CAST(0xB0400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (236, 1, 5, 3, CAST(0xB0400B00 AS Date), 200)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (237, 1, 4, 3, CAST(0xB0400B00 AS Date), 49)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (238, 1, 3, 3, CAST(0xB0400B00 AS Date), 41)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (239, 1, 2, 3, CAST(0xB0400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (240, 1, 1, 3, CAST(0xB0400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (241, 1, 6, 2, CAST(0xB0400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (242, 1, 5, 2, CAST(0xB0400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (243, 1, 4, 2, CAST(0xB0400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (244, 1, 3, 2, CAST(0xB0400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (245, 1, 2, 2, CAST(0xB0400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (246, 1, 1, 2, CAST(0xB0400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (247, 1, 6, 1, CAST(0xB0400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (248, 1, 5, 1, CAST(0xB0400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (249, 1, 4, 1, CAST(0xB0400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (250, 1, 3, 1, CAST(0xB0400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (251, 1, 2, 1, CAST(0xB0400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (252, 1, 1, 1, CAST(0xB0400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (253, 2, 1, 1, CAST(0xB1400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (254, 2, 2, 1, CAST(0xB1400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (255, 2, 3, 1, CAST(0xB1400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (256, 2, 4, 1, CAST(0xB1400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (257, 2, 5, 1, CAST(0xB1400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (258, 2, 6, 1, CAST(0xB1400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (259, 2, 1, 2, CAST(0xB1400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (260, 2, 2, 2, CAST(0xB1400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (261, 2, 3, 2, CAST(0xB1400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (262, 2, 4, 2, CAST(0xB1400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (263, 2, 5, 2, CAST(0xB1400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (264, 2, 6, 2, CAST(0xB1400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (265, 2, 1, 3, CAST(0xB1400B00 AS Date), 60)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (266, 2, 2, 3, CAST(0xB1400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (267, 2, 3, 3, CAST(0xB1400B00 AS Date), 44)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (268, 2, 4, 3, CAST(0xB1400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (269, 2, 5, 3, CAST(0xB1400B00 AS Date), 120)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (270, 2, 6, 3, CAST(0xB1400B00 AS Date), 100)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (271, 3, 6, 3, CAST(0xB2400B00 AS Date), 92)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (272, 3, 5, 3, CAST(0xB2400B00 AS Date), 90)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (273, 3, 4, 3, CAST(0xB2400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (274, 3, 3, 3, CAST(0xB2400B00 AS Date), 31)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (275, 3, 2, 3, CAST(0xB2400B00 AS Date), 31)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (276, 3, 1, 3, CAST(0xB2400B00 AS Date), 82)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (277, 3, 6, 2, CAST(0xB2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (278, 3, 5, 2, CAST(0xB2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (279, 3, 4, 2, CAST(0xB2400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (280, 3, 3, 2, CAST(0xB2400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (281, 3, 2, 2, CAST(0xB2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (282, 3, 1, 2, CAST(0xB2400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (283, 3, 6, 1, CAST(0xB2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (284, 3, 5, 1, CAST(0xB2400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (285, 3, 4, 1, CAST(0xB2400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (286, 3, 3, 1, CAST(0xB2400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (287, 3, 2, 1, CAST(0xB2400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (288, 3, 1, 1, CAST(0xB2400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (289, 4, 1, 1, CAST(0xB3400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (290, 4, 2, 1, CAST(0xB3400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (291, 4, 3, 1, CAST(0xB3400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (292, 4, 4, 1, CAST(0xB3400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (293, 4, 5, 1, CAST(0xB3400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (294, 4, 6, 1, CAST(0xB3400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (295, 4, 1, 2, CAST(0xB3400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (296, 4, 2, 2, CAST(0xB3400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (297, 4, 3, 2, CAST(0xB3400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (298, 4, 4, 2, CAST(0xB3400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (299, 4, 5, 2, CAST(0xB3400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (300, 4, 6, 2, CAST(0xB3400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (301, 4, 1, 3, CAST(0xB3400B00 AS Date), 81)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (302, 4, 2, 3, CAST(0xB3400B00 AS Date), 32)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (303, 4, 3, 3, CAST(0xB3400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (304, 4, 4, 3, CAST(0xB3400B00 AS Date), 35)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (305, 4, 5, 3, CAST(0xB3400B00 AS Date), 90)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (306, 4, 6, 3, CAST(0xB3400B00 AS Date), 120)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (307, 2, 1, 1, CAST(0x9C400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (308, 2, 2, 1, CAST(0x9C400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (309, 2, 3, 1, CAST(0x9C400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (310, 2, 4, 1, CAST(0x9C400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (311, 2, 5, 1, CAST(0x9C400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (312, 2, 6, 1, CAST(0x9C400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (313, 2, 1, 2, CAST(0x9C400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (314, 2, 2, 2, CAST(0x9C400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (315, 2, 3, 2, CAST(0x9C400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (316, 2, 4, 2, CAST(0x9C400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (317, 2, 5, 2, CAST(0x9C400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (318, 2, 6, 2, CAST(0x9C400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (319, 2, 1, 3, CAST(0x9C400B00 AS Date), 65)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (320, 2, 2, 3, CAST(0x9C400B00 AS Date), 25)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (321, 2, 3, 3, CAST(0x9C400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (322, 2, 4, 3, CAST(0x9C400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (323, 2, 5, 3, CAST(0x9C400B00 AS Date), 160)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (324, 2, 6, 3, CAST(0x9C400B00 AS Date), 160)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (325, 3, 6, 3, CAST(0x9D400B00 AS Date), 100)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (326, 3, 5, 3, CAST(0x9D400B00 AS Date), 130)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (327, 3, 4, 3, CAST(0x9D400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (328, 3, 3, 3, CAST(0x9D400B00 AS Date), 35)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (329, 3, 2, 3, CAST(0x9D400B00 AS Date), 32)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (330, 3, 1, 3, CAST(0x9D400B00 AS Date), 72)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (331, 3, 6, 2, CAST(0x9D400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (332, 3, 5, 2, CAST(0x9D400B00 AS Date), 15)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (333, 3, 4, 2, CAST(0x9D400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (334, 3, 3, 2, CAST(0x9D400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (335, 3, 2, 2, CAST(0x9D400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (336, 3, 1, 2, CAST(0x9D400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (337, 3, 6, 1, CAST(0x9D400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (338, 3, 5, 1, CAST(0x9D400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (339, 3, 4, 1, CAST(0x9D400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (340, 3, 3, 1, CAST(0x9D400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (341, 3, 2, 1, CAST(0x9D400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (342, 3, 1, 1, CAST(0x9D400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (343, 4, 1, 1, CAST(0x9E400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (344, 4, 2, 1, CAST(0x9E400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (345, 4, 3, 1, CAST(0x9E400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (346, 4, 4, 1, CAST(0x9E400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (347, 4, 5, 1, CAST(0x9E400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (348, 4, 6, 1, CAST(0x9E400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (349, 4, 1, 2, CAST(0x9E400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (350, 4, 2, 2, CAST(0x9E400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (351, 4, 3, 2, CAST(0x9E400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (352, 4, 4, 2, CAST(0x9E400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (353, 4, 5, 2, CAST(0x9E400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (354, 4, 6, 2, CAST(0x9E400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (355, 4, 1, 3, CAST(0x9E400B00 AS Date), 57)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (356, 4, 2, 3, CAST(0x9E400B00 AS Date), 36)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (357, 4, 3, 3, CAST(0x9E400B00 AS Date), 37)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (358, 4, 4, 3, CAST(0x9E400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (359, 4, 5, 3, CAST(0x9E400B00 AS Date), 120)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (360, 4, 6, 3, CAST(0x9E400B00 AS Date), 90)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (361, 5, 6, 3, CAST(0x9F400B00 AS Date), 70)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (362, 5, 5, 3, CAST(0x9F400B00 AS Date), 110)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (363, 5, 4, 3, CAST(0x9F400B00 AS Date), 60)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (364, 5, 3, 3, CAST(0x9F400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (365, 5, 2, 3, CAST(0x9F400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (366, 5, 1, 3, CAST(0x9F400B00 AS Date), 66)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (367, 5, 6, 2, CAST(0x9F400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (368, 5, 5, 2, CAST(0x9F400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (369, 5, 4, 2, CAST(0x9F400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (370, 5, 3, 2, CAST(0x9F400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (371, 5, 2, 2, CAST(0x9F400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (372, 5, 1, 2, CAST(0x9F400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (373, 5, 6, 1, CAST(0x9F400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (374, 5, 5, 1, CAST(0x9F400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (375, 5, 4, 1, CAST(0x9F400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (376, 5, 3, 1, CAST(0x9F400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (377, 5, 2, 1, CAST(0x9F400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (378, 5, 1, 1, CAST(0x9F400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (379, 6, 1, 1, CAST(0xA0400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (380, 6, 2, 1, CAST(0xA0400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (381, 6, 3, 1, CAST(0xA0400B00 AS Date), 9)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (382, 6, 4, 1, CAST(0xA0400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (383, 6, 5, 1, CAST(0xA0400B00 AS Date), 15)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (384, 6, 6, 1, CAST(0xA0400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (385, 6, 1, 2, CAST(0xA0400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (386, 6, 2, 2, CAST(0xA0400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (387, 6, 3, 2, CAST(0xA0400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (388, 6, 4, 2, CAST(0xA0400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (389, 6, 5, 2, CAST(0xA0400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (390, 6, 6, 2, CAST(0xA0400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (391, 6, 1, 3, CAST(0xA0400B00 AS Date), 60)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (392, 6, 2, 3, CAST(0xA0400B00 AS Date), 70)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (393, 6, 3, 3, CAST(0xA0400B00 AS Date), 16)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (394, 6, 4, 3, CAST(0xA0400B00 AS Date), 90)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (395, 6, 5, 3, CAST(0xA0400B00 AS Date), 300)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (396, 6, 6, 3, CAST(0xA0400B00 AS Date), 120)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (397, 7, 6, 3, CAST(0xA1400B00 AS Date), 313)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (398, 7, 5, 3, CAST(0xA1400B00 AS Date), 155)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (399, 7, 4, 3, CAST(0xA1400B00 AS Date), 78)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (400, 7, 3, 3, CAST(0xA1400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (401, 7, 2, 3, CAST(0xA1400B00 AS Date), 67)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (402, 7, 1, 3, CAST(0xA1400B00 AS Date), 74)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (403, 7, 6, 2, CAST(0xA1400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (404, 7, 5, 2, CAST(0xA1400B00 AS Date), 25)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (405, 7, 4, 2, CAST(0xA1400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (406, 7, 3, 2, CAST(0xA1400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (407, 7, 2, 2, CAST(0xA1400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (408, 7, 1, 2, CAST(0xA1400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (409, 7, 6, 1, CAST(0xA1400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (410, 7, 5, 1, CAST(0xA1400B00 AS Date), 25)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (411, 7, 4, 1, CAST(0xA1400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (412, 7, 3, 1, CAST(0xA1400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (413, 7, 2, 1, CAST(0xA1400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (414, 7, 1, 1, CAST(0xA1400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (415, 1, 1, 1, CAST(0xA2400B00 AS Date), 3)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (416, 1, 2, 1, CAST(0xA2400B00 AS Date), 7)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (417, 1, 3, 1, CAST(0xA2400B00 AS Date), 6)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (418, 1, 4, 1, CAST(0xA2400B00 AS Date), 8)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (419, 1, 5, 1, CAST(0xA2400B00 AS Date), 10)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (420, 1, 6, 1, CAST(0xA2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (421, 1, 1, 2, CAST(0xA2400B00 AS Date), 1)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (422, 1, 2, 2, CAST(0xA2400B00 AS Date), 2)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (423, 1, 3, 2, CAST(0xA2400B00 AS Date), 4)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (424, 1, 4, 2, CAST(0xA2400B00 AS Date), 5)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (425, 1, 5, 2, CAST(0xA2400B00 AS Date), 20)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (426, 1, 6, 2, CAST(0xA2400B00 AS Date), 0)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (427, 1, 1, 3, CAST(0xA2400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (428, 1, 2, 3, CAST(0xA2400B00 AS Date), 40)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (429, 1, 3, 3, CAST(0xA2400B00 AS Date), 30)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (430, 1, 4, 3, CAST(0xA2400B00 AS Date), 50)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (431, 1, 5, 3, CAST(0xA2400B00 AS Date), 175)
GO
INSERT [dbo].[Sale] ([ID], [DW], [ProductID], [BranchID], [SaleDate], [SaleCount]) VALUES (432, 1, 6, 3, CAST(0xA2400B00 AS Date), 60)
GO
SET IDENTITY_INSERT [dbo].[Sale] OFF
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UI_Product]    Script Date: 14.02.2020 0:28:52 ******/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Product]') AND name = N'UI_Product')
ALTER TABLE [dbo].[Product] ADD  CONSTRAINT [UI_Product] UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[DF__Remain__RemainCo__22751F6C]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Remain] ADD  DEFAULT ((0)) FOR [RemainCount]
END

GO
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[DF__Sale__SaleCount__236943A5]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Sale] ADD  DEFAULT ((0)) FOR [SaleCount]
END

GO
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[DF__SalesPlan__SaleP__245D67DE]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SalesPlan] ADD  DEFAULT ((0)) FOR [SalePlanCount]
END

GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_BoxType]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_BoxType] FOREIGN KEY([BoxTypeID])
REFERENCES [dbo].[BoxType] ([BoxTypeID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_BoxType]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_BoxType]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_Branch]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_LPlan_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[LoadPlan]'))
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_Product]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Product_BoxType]') AND parent_object_id = OBJECT_ID(N'[dbo].[Product]'))
ALTER TABLE [dbo].[Product]  WITH CHECK ADD  CONSTRAINT [FK_Product_BoxType] FOREIGN KEY([BoxTypeID])
REFERENCES [dbo].[BoxType] ([BoxTypeID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Product_BoxType]') AND parent_object_id = OBJECT_ID(N'[dbo].[Product]'))
ALTER TABLE [dbo].[Product] CHECK CONSTRAINT [FK_Product_BoxType]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Remain_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[Remain]'))
ALTER TABLE [dbo].[Remain]  WITH CHECK ADD  CONSTRAINT [FK_Remain_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Remain_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[Remain]'))
ALTER TABLE [dbo].[Remain] CHECK CONSTRAINT [FK_Remain_Branch]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Remain_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[Remain]'))
ALTER TABLE [dbo].[Remain]  WITH CHECK ADD  CONSTRAINT [FK_Remain_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Remain_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[Remain]'))
ALTER TABLE [dbo].[Remain] CHECK CONSTRAINT [FK_Remain_Product]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Sale_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[Sale]'))
ALTER TABLE [dbo].[Sale]  WITH CHECK ADD  CONSTRAINT [FK_Sale_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Sale_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[Sale]'))
ALTER TABLE [dbo].[Sale] CHECK CONSTRAINT [FK_Sale_Branch]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Sale_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[Sale]'))
ALTER TABLE [dbo].[Sale]  WITH CHECK ADD  CONSTRAINT [FK_Sale_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Sale_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[Sale]'))
ALTER TABLE [dbo].[Sale] CHECK CONSTRAINT [FK_Sale_Product]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SPlan_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[SalesPlan]'))
ALTER TABLE [dbo].[SalesPlan]  WITH CHECK ADD  CONSTRAINT [FK_SPlan_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SPlan_Branch]') AND parent_object_id = OBJECT_ID(N'[dbo].[SalesPlan]'))
ALTER TABLE [dbo].[SalesPlan] CHECK CONSTRAINT [FK_SPlan_Branch]
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SPlan_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[SalesPlan]'))
ALTER TABLE [dbo].[SalesPlan]  WITH CHECK ADD  CONSTRAINT [FK_SPlan_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SPlan_Product]') AND parent_object_id = OBJECT_ID(N'[dbo].[SalesPlan]'))
ALTER TABLE [dbo].[SalesPlan] CHECK CONSTRAINT [FK_SPlan_Product]
GO
USE [master]
GO
ALTER DATABASE [VkusVill] SET  READ_WRITE 
GO
