/*==============================================================================
 Datei  : 05_Bad View.sql
 Thema  : Sichten (Views) - Nutzen, Vorteile und Fallstricke ("Bad View")

 WOFUER SIND VIEWS?
   Eine View ist eine gespeicherte SELECT-Abfrage mit Namen. Sie speichert
   keine Daten, sondern wird bei jedem Aufruf neu aufgeloest.

 VORTEILE
   - Komplexe Joins einmal schreiben, ueberall wiederverwenden
   - Sicherheit: Benutzer bekommen Rechte auf die View, nicht auf die Tabelle
     (Spalten/Zeilen ausblenden)
   - Abstraktion: Tabellenstruktur kann hinter der View versteckt werden
   - Mit Index (indizierte View) kann das Ergebnis materialisiert werden

 WANN SIND VIEWS SCHLECHT?
   - SELECT * in der View: Die Spaltenliste wird beim Erstellen festgelegt.
     Spaetere Aenderungen der Tabelle (neue/geloeschte Spalten) werden NICHT
     automatisch uebernommen -> fehlende oder verschobene Spalten (siehe unten)
   - Views auf Views auf Views: schwer nachvollziehbar, Performance-Probleme
   - Views sind kein Performance-Gewinn (kein gespeicherter Plan/Ergebnis)
   - ORDER BY ist in Views nicht erlaubt (ohne TOP)

 PRAXISTIPPS
   1. Nie SELECT * in Views, immer Spalten explizit auflisten
   2. Bei Strukturaenderungen: EXEC sp_refreshview 'viewname'
   3. WITH SCHEMABINDING verhindert, dass zugrundeliegende Tabellen/Spalten
      geaendert werden, die die View braucht (Voraussetzung fuer indizierte
      Views; dann Schemaname verwenden: dbo.tabelle)
   4. Views flach halten (maximal 1-2 Ebenen)
   5. Aussagekraeftige Namen mit Praefix (z.B. v...) verwenden
==============================================================================*/

USE Northwind;
GO

DROP VIEW IF EXISTS vslf;
DROP VIEW IF EXISTS vKundeUmsatz;
DROP TABLE IF EXISTS slf;
GO

-- Tabelle mit Spalten S L F (Stadt Land Fluss :-)
CREATE TABLE slf (id INT IDENTITY, stadt INT, land INT);
GO

-- 3 Datensaetze: 10er = Stadt, 100er = Land
INSERT INTO slf
SELECT 10, 100
UNION ALL
SELECT 20, 200
UNION ALL
SELECT 30, 300;
GO

-- So sieht es aus
SELECT * FROM slf;
GO

-- Sicht mit SELECT * (BAD!)
CREATE VIEW vslf
AS
SELECT * FROM slf;
GO

-- So sieht es aus
SELECT * FROM vslf;
GO

-- Nun eine Spalte dazu: F wie Fluss
ALTER TABLE slf ADD Fluss INT;
GO

-- Und 1000er Werte fuer Fluss
UPDATE slf SET Fluss = id * 1000;
GO

-- Und was kommt raus? Fluss fehlt in der View! (Spaltenliste ist "eingefroren")
SELECT * FROM vslf;
GO

-- Nun Spalte weg
ALTER TABLE slf DROP COLUMN Land;
GO

-- Und was kommt raus? Die View ist veraltet: Die Spalten sind verschoben,
-- d.h. die Fluss-Werte stehen unter dem Spaltennamen "land"
SELECT * FROM vslf;
GO

-- Abhilfe 1: View aktualisieren (jetzt stimmt die Spaltenliste wieder)
EXEC sp_refreshview 'vslf';
GO
SELECT * FROM vslf;
GO

-- Abhilfe 2 (besser): explizite Spalten + SCHEMABINDING
-- (jetzt muss man genau arbeiten!)
CREATE OR ALTER VIEW vslf WITH SCHEMABINDING
AS
SELECT id, stadt, Fluss FROM dbo.slf;
GO

SELECT * FROM vslf;
GO

-- Spalte kann jetzt nicht mehr gedroppt werden (Fehler ist gewollt):
-- ALTER TABLE slf DROP COLUMN Fluss;

-- Views im System anzeigen
SELECT * FROM sys.views;

SELECT * FROM INFORMATION_SCHEMA.VIEWS
WHERE VIEW_DEFINITION LIKE '%schemabinding%';
GO

-- Praxisbeispiel: Join ueber mehrere Tabellen als View kapseln
CREATE VIEW vKundeUmsatz
AS
SELECT Customers.CompanyName, Customers.City, Customers.Country,
       Employees.LastName, Employees.FirstName,
       Orders.OrderDate, Orders.Freight,
       [Order Details].UnitPrice, [Order Details].Quantity, [Order Details].ProductID,
       Products.ProductName
FROM Customers
     INNER JOIN Orders ON Customers.CustomerID = Orders.CustomerID
     INNER JOIN Employees ON Orders.EmployeeID = Employees.EmployeeID
     INNER JOIN [Order Details] ON Orders.OrderID = [Order Details].OrderID
     INNER JOIN Products ON [Order Details].ProductID = Products.ProductID;
GO

SELECT * FROM vKundeUmsatz;

-- Achtung: Die View liefert eine Zeile pro Bestellposition,
-- Zaehlungen unterscheiden sich daher von der Basistabelle
SELECT country, COUNT(*) FROM vKundeUmsatz
GROUP BY country;

SELECT country, COUNT(*) FROM customers
GROUP BY country;
GO
