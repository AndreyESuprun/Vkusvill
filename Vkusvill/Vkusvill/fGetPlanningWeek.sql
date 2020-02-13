use VkusVill;
go
if exists (select * from sys.all_objects where name = 'fGetPlanningWeek') drop function fGetPlanningWeek
go
/*
функция получения недельного набора дат с указанием дней недели, начиная с даты из параметра
*/
create function fGetPlanningWeek(@FirstPlanDay date)
returns table 
as 
	return 
	with cte as (select @FirstPlanDay as d union all 
					select Dateadd(day,1,d) from cte) 
					select top 7 d, DATEPART(DW, d) as dw from cte 
go


select * from dbo.fGetPlanningWeek('20200206')