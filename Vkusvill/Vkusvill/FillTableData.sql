USE [VkusVill]
GO
/****** Object:  Table [dbo].[BoxType]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[BoxType](
	[BoxTypeID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[CountOfUnits] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[BoxTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Branch]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Branch](
	[BranchID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[BranchAddress] [varchar](128) NULL,
PRIMARY KEY CLUSTERED 
(
	[BranchID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LoadPlan]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LoadPlan](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[LoadPlanDate] [date] NULL,
	[DW] [int] NULL,
	[BranchID] [int] NULL,
	[ProductID] [int] NULL,
	[BoxTypeID] [int] NULL,
	[LoadPlanBoxCount] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Product]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Product](
	[ProductID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
	[BoxTypeID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UI_Product] UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Remain]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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

GO
/****** Object:  Table [dbo].[Sale]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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

GO
/****** Object:  Table [dbo].[SalesPlan]    Script Date: 06.02.2020 22:50:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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

GO
ALTER TABLE [dbo].[Remain] ADD  DEFAULT ((0)) FOR [RemainCount]
GO
ALTER TABLE [dbo].[Sale] ADD  DEFAULT ((0)) FOR [SaleCount]
GO
ALTER TABLE [dbo].[SalesPlan] ADD  DEFAULT ((0)) FOR [SalePlanCount]
GO
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_BoxType] FOREIGN KEY([BoxTypeID])
REFERENCES [dbo].[BoxType] ([BoxTypeID])
GO
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_BoxType]
GO
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_Branch]
GO
ALTER TABLE [dbo].[LoadPlan]  WITH CHECK ADD  CONSTRAINT [FK_LPlan_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
ALTER TABLE [dbo].[LoadPlan] CHECK CONSTRAINT [FK_LPlan_Product]
GO
ALTER TABLE [dbo].[Product]  WITH CHECK ADD  CONSTRAINT [FK_Product_BoxType] FOREIGN KEY([BoxTypeID])
REFERENCES [dbo].[BoxType] ([BoxTypeID])
GO
ALTER TABLE [dbo].[Product] CHECK CONSTRAINT [FK_Product_BoxType]
GO
ALTER TABLE [dbo].[Remain]  WITH CHECK ADD  CONSTRAINT [FK_Remain_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
ALTER TABLE [dbo].[Remain] CHECK CONSTRAINT [FK_Remain_Branch]
GO
ALTER TABLE [dbo].[Remain]  WITH CHECK ADD  CONSTRAINT [FK_Remain_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
ALTER TABLE [dbo].[Remain] CHECK CONSTRAINT [FK_Remain_Product]
GO
ALTER TABLE [dbo].[Sale]  WITH CHECK ADD  CONSTRAINT [FK_Sale_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
ALTER TABLE [dbo].[Sale] CHECK CONSTRAINT [FK_Sale_Branch]
GO
ALTER TABLE [dbo].[Sale]  WITH CHECK ADD  CONSTRAINT [FK_Sale_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
ALTER TABLE [dbo].[Sale] CHECK CONSTRAINT [FK_Sale_Product]
GO
ALTER TABLE [dbo].[SalesPlan]  WITH CHECK ADD  CONSTRAINT [FK_SPlan_Branch] FOREIGN KEY([BranchID])
REFERENCES [dbo].[Branch] ([BranchID])
GO
ALTER TABLE [dbo].[SalesPlan] CHECK CONSTRAINT [FK_SPlan_Branch]
GO
ALTER TABLE [dbo].[SalesPlan]  WITH CHECK ADD  CONSTRAINT [FK_SPlan_Product] FOREIGN KEY([ProductID])
REFERENCES [dbo].[Product] ([ProductID])
GO
ALTER TABLE [dbo].[SalesPlan] CHECK CONSTRAINT [FK_SPlan_Product]
GO
