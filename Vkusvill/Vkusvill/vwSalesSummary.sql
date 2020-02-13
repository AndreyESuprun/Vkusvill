
use VkusVill;
go
if exists
(select * from sys.all_objects where name = 'vwSalesSummary')
	drop view vwSalesSummary
go

create view vwSalesSummary
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
