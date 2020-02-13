use VkusVill;
go
if exists (select * from sys.all_objects where name = 'pCalculatePlan') drop procedure pCalculatePlan
go
/*

��������� ��������� �������� ������ 
�� ���� ������ �� ����
�� ��������� ������ ���������� ������
� ����������� �� ��� ������,
������� ������������ � ������� SalesPlan

������� �������� ���� �� ������ �������� �������� ��� ���������������� ��� ������ �� ���������� ��������,
����, ���� ���������� ������������� ���� (��� ��������) �� ������ � ������, �� ������� ������� ����� 
�������, �������� ���� ���������, ��������� �� ����������� ������ �������� (��� ��������)

*/
create procedure pCalculatePlan
	
	@FirstPlanDay date, -- ����, � ������� ����� ��������������� �������
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
go