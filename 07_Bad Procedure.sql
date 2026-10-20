use demoDb
GO

drop table if exists kundeumsatz;
GO

select * into spdemo from northwind.dbo.KUNDEUMSATZ
GO

select top 1 (select count(*) from spdemo) as Zeilen,*  
from spdemo
GO

create nonclustered index ix on spdemo (id)
GO

set statistics io, time on 


select * from spdemo where id < 12000
GO

create or alter proc gp_spdemo @par1 int
as
select * from spdemo where id < @par1
GO

exec gp_spdemo 12000

---so weit so gut: Proc vs Adhoc

select * from spdemo where id < 900000
--> Messung ?
exec gp_spdemo 900000


select * into spdemo2 from spdemo

create nonclustered index ix on spdemo2 (id)

create or alter procedure sp_gpdemo2 @par1 int, @bit bit 
as
If @bit = 0 select * from spdemo2 where id < @par1
If @bit =1 select * from spdemo2 where id > @par1

set statistics io, time on
exec  sp_gpdemo2 300000,1
exec  sp_gpdemo2 1000,1