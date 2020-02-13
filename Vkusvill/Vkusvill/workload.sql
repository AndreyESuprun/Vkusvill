/*

 to do
процедура для создания плана продаж

+ определение дельт
+ определение трендов
* формирование прогноза

- анализ прогнозов --> тестирование результатов
- запрос вьюха для анализа результатов
- генерим датаьейс скрипт
- периоды во вьюхе прогнозов продаж (убрать лишнее)
- заливка на гитхаб
- письмо хрюше

+ trouble with avgdelta
+ ограничить прогноз во времени - придумать, как работать с датой прогноза во вьюхах --> во вьюху зашито 

+! BUG - with IsTrend And other Prediction Column in group --> added f**ng subqueries, 
	but problem is in another side 
	- in the view (NO BUG BUT FEATURE):
	this version of view dont support different variants of prognoses dependly of deep of analyse (count of previously weeks)

	-! to decide - Do have we need that fucntional of view or harcode in view deep interval of analyze (ex. - 1 month)

+ todo заполнить таблицу SalesPlan - нужно для отладки pCalculateLoad --> done

-! todo заполнение LoadPlan


*/