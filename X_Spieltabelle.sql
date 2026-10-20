SELECT        Customers.CustomerID, Customers.CompanyName, Customers.ContactName, Customers.ContactTitle, Customers.City, Customers.Country, Orders.EmployeeID, Orders.OrderDate, Orders.Freight, Orders.ShipName, 
                         Orders.ShipCity, Orders.ShipCountry, Employees.LastName, Employees.FirstName, [Order Details].OrderID, [Order Details].ProductID, [Order Details].UnitPrice, [Order Details].Quantity, Products.ProductName, 
                         Products.UnitsInStock
INTO KU --wird eine Tabelle mit den Daten der Abfrage. alle Datentypn und IDentity 
		--werden mitgenommen
FROM            Customers INNER JOIN
                         Orders ON Customers.CustomerID = Orders.CustomerID INNER JOIN
                         Employees ON Orders.EmployeeID = Employees.EmployeeID INNER JOIN
                         [Order Details] ON Orders.OrderID = [Order Details].OrderID INNER JOIN
                         Products ON [Order Details].ProductID = Products.ProductID

--alles was drin ist nochmal rein..bis 551000 betroffen-- 1,1 Mio Datensätze
insert into ku
select * from ku

--erste Kopie zum Spielen
select * into ku1 from ku

--Identity Wert dazunehmen
alter table ku1 add ID int identity --> Problem der forward_record_count wird erzeugt


