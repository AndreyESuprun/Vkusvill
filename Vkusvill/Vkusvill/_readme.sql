-- всем привет, это тестовый проект - задание на соискание должности программист SQL для компании "Вкусвилл"
-- задание цмтирую:

/*
	"Компания занимается розничней торговлей продуктами питания. Компания быстрорастущая в настоящий момент более 1000 магазинов. 
Главной особенностью является ежедневное распределение товаров с нескольких распределительных центров на торговые точки.
Распределение товаров выполняется исходя из показателей, кратно количеству товара в коробке: 
1) План продаж на день недели(рассчитывается еженедельно на несколько дней вперед исходя из статистики продаж)
2) Остаток товара на магазине
по формуле КоличествоКоробокТОвара на магазин = ОкруглиДоКоробкиВверх(ПланПродаж - Остаток товара на магазине)
 
Необходимо реализовать основные таблицы и процедуру распределения товара на день недели."

*/

-- Итак приступим:
-- Для создания БД приготовлен файл: DatabaseScript.sql, созданный средствами SSMS уже после завершения задания
-- код запилен с помощью:
-- Microsoft SQL Server 2012 - 11.0.2100.60 (X64) 
-- Developer Edition (64-bit) on Windows NT 6.2 <X64> (Build 9200: ) (Hypervisor)


-- Таблицы БД
-- тут храним тару - коробочки и прочие
select * from [dbo].[BoxType]
-- тут наши с вами товары (c привязкой к таре)
select * from [dbo].[Product]
-- товары продают в торговых точках (ТТ)
select * from [dbo].[Branch]

-- продажи фиксируем в этой таблице за сутки в каждой ТТ 
-- по каждому товару показано количество проданых единиц - SaleCount
-- колонка DW - день недели (1-7)
-- нынешние данные - плод фантазии
select top 8 * from [dbo].[Sale]
-- остаток каждого товара в каждом магазине на конец суток - RemainCount
select top 8 * from [dbo].[Remain]

-- для формирования еженедельно плана продаж на неделю используем ХП,
-- она берет данные из Sales и пытается предсказать последующие продажи
-- в коде ХП описано, как она подсчитывает (its magic..)

EXECUTE [dbo].[pCalculatePlan] 
   @FirstPlanDay = '2020-02-06'		-- первый день недельного прогноза

-- план продаж после работы ХП записывается в таблицу SalesPlan

-- Посмотрим запросом, шо там нассчитали

select 'Продажа совершонная' as Comment, 
	s.DW, s.SaleDate, b.Name as Branch, p.Name as Product, s.SaleCount
from Sale s
	inner join Product p on p.ProductID = s.ProductID
	inner join Branch b on b.BranchID = s.BranchID
where s.ProductID = 2
	
union
select 'Продажа предсказанная' as Comment, 
	s.DW, s.SalePlanDate as SaleDate, b.Name as Branch, p.Name as Product, s.SalePlanCount as SaleCount
	from SalesPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2
	
order by Branch, DW, SaleDate


-- теперь нужно определить сколько коробочек каждого продукта
-- нужно заслать в каждую ТТ, так чтоб хватило

EXECUTE [dbo].[pCalculateLoad] 
   @FirstDay = '2020-02-06'			-- первый день после приемки нашей рассчитанной поставки
  ,@DayCount = 3					-- количество дней, на которое нужно спрогнозировать  поставку

-- после работы этой ХП план отгрузок помещается в таблицу LoadPlan
-- каждая отгрузка ограничена от другой только ее датой LoadPlanDate
-- если в Remain недостаточно данных, процедура вычисляет остаток пна основе фактических продаж

select 'Остаток товара' as Comment, b.Name as Branch, p.Name as Product, RemainDate as [Date], RemainCount as [Count], null as BoxCount
from Remain s
	inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
where s.ProductID = 2
union
select 'Продажа предсказанная' as Comment, 
	b.Name as Branch, p.Name as Product, s.SalePlanDate as [Date], s.SalePlanCount as [Count], null as BoxCount
	from SalesPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2
		and s.SalePlanDate between '20200206' and '20200208'
union
select 'Планируемая Отгрузка' as Comment, 
	b.Name as Branch, p.Name as Product, s.LoadPlanDate as [Date], s.LoadPlanBoxCount * bt.CountOfUnits as [Count], LoadPlanBoxCount as BoxCount
	from LoadPlan s
		inner join Product p on p.ProductID = s.ProductID
		inner join BoxType bt on bt.BoxTypeID = p.BoxTypeID
		inner join Branch b on b.BranchID = s.BranchID
	where s.ProductID = 2

order by Branch, Comment



-- !! ВНИМАНИЕ !!
-- все работает исключительно на тестовых примерах - 
-- не пытайтесь повторить на реальных данных