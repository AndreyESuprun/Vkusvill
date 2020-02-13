-- ���� ������, ��� �������� ������ - ������� �� ��������� ��������� ����������� SQL ��� �������� "��������"
-- ������� �������:

/*
	"�������� ���������� ��������� ��������� ���������� �������. �������� �������������� � ��������� ������ ����� 1000 ���������. 
������� ������������ �������� ���������� ������������� ������� � ���������� ����������������� ������� �� �������� �����.
������������� ������� ����������� ������ �� �����������, ������ ���������� ������ � �������: 
1) ���� ������ �� ���� ������(�������������� ����������� �� ��������� ���� ������ ������ �� ���������� ������)
2) ������� ������ �� ��������
�� ������� ����������������������� �� ������� = ���������������������(���������� - ������� ������ �� ��������)
 
���������� ����������� �������� ������� � ��������� ������������� ������ �� ���� ������."

*/

-- ���� ���������:
-- ��� �������� �� ����������� ����: DatabaseScript.sql, ��������� ���������� SSMS ��� ����� ���������� �������
-- ��� ������� � �������:
-- Microsoft SQL Server 2012 - 11.0.2100.60 (X64) 
-- Developer Edition (64-bit) on Windows NT 6.2 <X64> (Build 9200: ) (Hypervisor)


-- ������� ��
-- ��� ������ ���� - ��������� � ������
select * from [dbo].[BoxType]
-- ��� ���� � ���� ������ (c ��������� � ����)
select * from [dbo].[Product]
-- ������ ������� � �������� ������ (��)
select * from [dbo].[Branch]

-- ������� ��������� � ���� ������� �� ����� � ������ �� 
-- �� ������� ������ �������� ���������� �������� ������ - SaleCount
-- ������� DW - ���� ������ (1-7)
-- �������� ������ - ���� ��������
select top 8 * from [dbo].[Sale]
-- ������� ������� ������ � ������ �������� �� ����� ����� - RemainCount
select top 8 * from [dbo].[Remain]

-- ��� ������������ ����������� ����� ������ �� ������ ���������� ��,
-- ��� ����� ������ �� Sales � �������� ����������� ����������� �������
-- � ���� �� �������, ��� ��� ������������ (its magic..)

EXECUTE [dbo].[pCalculatePlan] 
   @FirstPlanDay = '2020-02-06'		-- ������ ���� ���������� ��������

-- ���� ������ ����� ������ �� ������������ � ������� SalesPlan

-- ��������� ��������, �� ��� ����������

select '������� �����������' as Comment, 
	s.DW, s.SaleDate, b.Name as Branch, p.Name as Product, s.SaleCount
from Sale s
	inner join Product p on p.ProductID = s.ProductID
	inner join Branch b on b.BranchID = s.BranchID
where s.ProductID = 2
	
union
select '������� �������������' as Comment, 
	s.DW, s.SalePlanDate as SaleDate, b.Name as Branch, p.Name as Product, s.SalePlanCount as SaleCount
	from SalesPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2
	
order by Branch, DW, SaleDate


-- ������ ����� ���������� ������� ��������� ������� ��������
-- ����� ������� � ������ ��, ��� ���� �������

EXECUTE [dbo].[pCalculateLoad] 
   @FirstDay = '2020-02-06'			-- ������ ���� ����� ������� ����� ������������ ��������
  ,@DayCount = 3					-- ���������� ����, �� ������� ����� ���������������  ��������

-- ����� ������ ���� �� ���� �������� ���������� � ������� LoadPlan
-- ������ �������� ���������� �� ������ ������ �� ����� LoadPlanDate
-- ���� � Remain ������������ ������, ��������� ��������� ������� ��� ������ ����������� ������

select '������� ������' as Comment, b.Name as Branch, p.Name as Product, RemainDate as [Date], RemainCount as [Count], null as BoxCount
from Remain s
	inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
where s.ProductID = 2
union
select '������� �������������' as Comment, 
	b.Name as Branch, p.Name as Product, s.SalePlanDate as [Date], s.SalePlanCount as [Count], null as BoxCount
	from SalesPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2
		and s.SalePlanDate between '20200206' and '20200208'
union
select '����������� ��������' as Comment, 
	b.Name as Branch, p.Name as Product, s.LoadPlanDate as [Date], s.LoadPlanBoxCount * bt.CountOfUnits as [Count], LoadPlanBoxCount as BoxCount
	from LoadPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join BoxType bt on bt.BoxTypeID = p.BoxTypeID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2

order by Branch, Comment



-- !! �������� !!
-- ��� �������� ������������� �� �������� �������� - 
-- �� ��������� ��������� �� �������� ������