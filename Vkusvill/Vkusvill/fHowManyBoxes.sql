use VkusVill;
go
if exists (select * from sys.all_objects where name = 'fHowManyBoxes') drop function fHowManyBoxes
go
create function fHowManyBoxes(@NeccesaryCount int, @BoxCapacity int)
	returns int	
as
begin
	return 
		(select 
			case	when @NeccesaryCount/@BoxCapacity * @BoxCapacity < @NeccesaryCount 
						then @NeccesaryCount/@BoxCapacity + 1 
					when @NeccesaryCount < 0 then 0
					else @NeccesaryCount/@BoxCapacity 
			end)

end
go




select dbo.fHowManyBoxes(144, 27) fHowManyBoxes






