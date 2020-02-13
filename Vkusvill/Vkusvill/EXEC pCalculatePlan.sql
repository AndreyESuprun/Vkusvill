USE [VkusVill]
GO

DECLARE @RC int
DECLARE @Day date
DECLARE @ProductID int
DECLARE @BranchID int

-- TODO: Set parameter values here.

EXECUTE @RC = [dbo].[pCalculatePlan] 
   @FirstAnalizeDay = '2020-01-02'
  ,@FirstPlanDay = '2020-02-06'
  ,@ProductID = null
  ,@BranchID = null
GO


