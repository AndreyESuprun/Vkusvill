use VkusVill; declare @ProductID int, @Date date, @BranchID int, @DW int

select
		@Date = '20200206',
		@BranchID = 3,
		@ProductID = 6,
		@DW = null

select  s.*

	--s.ProductID
	--,s.BranchID
	--,s.DW
	,avg(SaleCount) over (partition by ProductID, DW, BranchID) as AvgDWCount
	, min(SaleCount) over (partition by ProductID, DW, BranchID) as MinDWCount
	, max(SaleCount) over (partition by ProductID, DW, BranchID) as MaxDWCount
from Sale s 
where 
	SaleCount <> 0
	and (BranchID = @BranchID or @BranchID is null)
	and (ProductID = @ProductID or @ProductID is null)
	and (DW = @DW or @DW is null)
order by SaleDate desc, ProductID, BranchID, DW


select ProductID, p.Name, b.BoxTypeID , b.CountOfUnits
from Product p
	inner join BoxType b on b.BoxTypeID = p.BoxTypeID

	select * from LoadPlan;
	select * from SalesPlan;