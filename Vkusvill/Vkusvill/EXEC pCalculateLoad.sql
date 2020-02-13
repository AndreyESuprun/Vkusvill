USE [VkusVill]
GO

DECLARE @RC int
DECLARE @FirstDay date
DECLARE @DayCount int
DECLARE @ProductID int
DECLARE @BranchID int

-- TODO: Set parameter values here.

EXECUTE @RC = [dbo].[pCalculateLoad] 
   @FirstDay = '2020-02-06'
  ,@DayCount = 3
  ,@ProductID = null
  ,@BranchID = null

select @rc as '@RC';
GO


