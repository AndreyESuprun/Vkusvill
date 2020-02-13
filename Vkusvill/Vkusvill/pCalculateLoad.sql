use VkusVill;
go
if exists (select * from sys.all_objects where name = 'pCalculateLoad') drop procedure pCalculateLoad
go
/*	����������������� ��������
	-- ��������� ������� ��� ������� ������� �������� ���� ������� � ������ ������� �������� - � ������
	-- ������������ �������� ������ �� ���� ������ - � ������
	-- ��������� ����������� ������� ������ ��� �������� - � ��������
	
*/

create procedure pCalculateLoad
	
	@FirstDay date, -- ������ ���� ������� ��� �������� ��������
	@DayCount int, -- ����� ���� � ������� ��� �������� ��������
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
				sum(r.RemainCount) as RemainCount, -- RemainCount - ������� �� ��������� ��������� ����� 
				isnull(sum(clcsls.SaleCount), 0) as UnaccountedSales, -- UnaccountedSales - �������������� �������
				sum(clcprd.SumPlanCount) as SumPlanCount, -- ������������� ������
				sum(clcprd.SumPlanCount) 
					- sum(r.RemainCount) 
					+ isnull(sum(clcsls.SaleCount), 0)  
						as CountToLoad,					-- ������ � ��������
				dbo.fHowManyBoxes(sum(clcprd.SumPlanCount) 
					- sum(r.RemainCount) 
					+ isnull(sum(clcsls.SaleCount), 0) , box.CountOfUnits) as BoxToLoad	-- �������� � ��������
		
			from 
				(   
					select
						BranchID, ProductID, RemainDate, RemainCount, 
						ROW_NUMBER() over (partition by BranchID, ProductID order by RemainDate desc) RN
					from Remain 
					where (ProductID = @ProductID or @ProductID is null) and (BranchID = @BranchID or @BranchID is null)
						and  RemainDate < @FirstDay
				) as r	-- �������� ������� �������

				left join 
				(
					select BranchID, ProductID, SaleDate, SaleCount
					from vwSalesSummary
				) as clcsls	 -- � ������ ������������� ����������� ������� �� ������ ��������
						on clcsls.BranchID = r.BranchID and clcsls.ProductID = r.ProductID 
						and clcsls.SaleDate > r.RemainDate and SaleDate < @FirstDay
		 
				inner join
				(
					select BranchID, ProductID, sum(SalePlanCount) SumPlanCount
					from SalesPlan
					where SalePlanDate >= @FirstDay and SalePlanDate < DATEADD(DAY, @DayCount, @FirstDay) 
					group by BranchID, ProductID
				) as clcprd -- �������� �������
					on clcprd.ProductID = r.ProductID and clcprd.BranchID = r.BranchID

				inner join
				(
					select ProductID, b.CountOfUnits, b.BoxTypeID
					from Product p
						inner join BoxType b on b.BoxTypeID = p.BoxTypeID
				) as box -- �������� ���������
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
go