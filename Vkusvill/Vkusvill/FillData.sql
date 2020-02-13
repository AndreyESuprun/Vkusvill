use VkusVill;



insert into BoxType (Name, CountOfUnits)
select 'ящик пиваса', 20 union
select 'лоток яиц 10', 10 union
select 'лоток яиц 30', 30 union
select 'коробка для печенья', 21 union
select 'пак минералки', 6 union
select 'коробка для всего', 27


insert into Product (Name, BoxTypeID)
select 'Пиво Крым 0.5', 6 union
select 'Печенье Бельвита', 2 union
select 'Яйцо Куриное Окт с1', 3 union
select 'Яйцо Куруное Кра с2', 4 union
select 'Молоко Коровье', 1 union
select 'ПепсиКола', 5


insert into Branch (Name, BranchAddress)
select 'Магаз На Районе','Севастополь, ул.Л.Чайкиной, 57' union
select 'Супермаркет в ТЦ','Симферополь, Объездная, 201' union
select 'Сельский магаз','с.Дубки, Ленина, 21' 

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
