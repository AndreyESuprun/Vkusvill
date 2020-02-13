use VkusVill;



insert into BoxType (Name, CountOfUnits)
select '���� ������', 20 union
select '����� ��� 10', 10 union
select '����� ��� 30', 30 union
select '������� ��� �������', 21 union
select '��� ���������', 6 union
select '������� ��� �����', 27


insert into Product (Name, BoxTypeID)
select '���� ���� 0.5', 6 union
select '������� ��������', 2 union
select '���� ������� ��� �1', 3 union
select '���� ������� ��� �2', 4 union
select '������ �������', 1 union
select '���������', 5


insert into Branch (Name, BranchAddress)
select '����� �� ������','�����������, ��.�.��������, 57' union
select '����������� � ��','�����������, ���������, 201' union
select '�������� �����','�.�����, ������, 21' 

use VkusVill;
with cte (ProductID, BranchID, SaleDate, SaleCount) as
(
	select ProductID, BranchID, cast('20200113' as date) as SaleDate, 0 from Product, Branch
	union all
	select ProductID, BranchID, DATEADD(DAY, 1, cte.SaleDate) as SaleDate, 0 from cte  
	where SaleDate < cast('20200119' as date)
)
insert into Sale (ProductID, BranchID, SaleDate, DW, SaleCount)
select  ProductID, BranchID, SaleDate, DATEPART(DW, SaleDate), SaleCount from cte
order by SaleDate;

insert into Remain (BranchID, ProductID, RemainDate, RemainCount)
select BranchID, ProductID, '20200205' as RemainDate, 0 as RemainCount  
from Branch , Product

select * from BoxType;
select * from Product;
select * from Branch;
select * from Sale where saledate = '2020-01-28';
select * from Remain;
