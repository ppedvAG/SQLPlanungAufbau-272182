USE NORTHWIND;
GO

drop table if exists slf
drop view if exists vslf

--Tabelle mit Spalte S L F (Stadt Land Fluss :-)
create table slf(id int identity, stadt int, land int)
GO

-- 3 Datensätze: 10er = Stadt , 100er = Land
insert into slf
select 10,100
UNION ALL
select 20, 200
UNION ALL
select 30, 300

--so siehts aus..
select * from slf

--Sicht 
create view vslf 
as
select * from slf
GO

--So siehts aus
select * from vslf


--nun eine Spalte dazu . F  Fuss

alter table slf add Fluss int

--und 1000er Werte für Fluss
update slf set fluss = id * 1000
GO

--und was kommt raus??

select * from vslf
GO

--und nun  Spalte weg
alter table slf drop column Land
GO

--und was kommt raus?
select * from vslf









--Sicht 
create or alter view vslf with schemabinding --jetzt musste genau arbeiten!! ätsch
as
select id, stadt, fluss from dbo.slf

select * from vslf

alter table slf add Fluss int
update slf set fluss = id * 1000


select * from sys.views

select * from [INFORMATION_SCHEMA].[VIEWS]
where VIEW_DEFINITION like '%schemabinding%'


create view vKundeUmsatz
as
SELECT        Customers.CompanyName, Customers.City, Customers.Country, Employees.LastName, Employees.FirstName, Orders.OrderDate, Orders.Freight, [Order Details].UnitPrice, [Order Details].Quantity, [Order Details].ProductID, 
                         Products.ProductName
FROM            Customers INNER JOIN
                         Orders ON Customers.CustomerID = Orders.CustomerID INNER JOIN
                         Employees ON Orders.EmployeeID = Employees.EmployeeID INNER JOIN
                         [Order Details] ON Orders.OrderID = [Order Details].OrderID INNER JOIN
                         Products ON [Order Details].ProductID = Products.ProductID


select * from vKundeUmsatz

select country, count(*) from vKundeUmsatz
group by country


select country, count(*) from customers
group by country

--Prozeduren.. Warum?
--ähnlich wie Windows Batchdateien
--Proz kann INS UP DEL SEL .. enthalten

--aufruf

exec procname 100

create or alter proc gpdemo @par1 int, @par2 int
as
Code
(INS UP DEL SEL SEL SEL..)



create or alter proc gpdemo @zahl1 int
as
select @zahl1 *100
GO

exec gpdemo 10

--Prozeduren sind schneller, weil Plan kompiliert vorliegt auch nach Neustart
--beim ersten Aufruf


select * from orders where orderid = 10250


select * from slf
select * from vslf --fluss

alter table slf drop column land

select * from vslf
