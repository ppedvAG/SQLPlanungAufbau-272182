/*==============================================================================
 Datei  : 07_Bad Procedure.sql
 Thema  : Gespeicherte Prozeduren (Stored Procedures) - "Bad Procedure"

 WOFUER SIND PROZEDUREN?
   Aehnlich wie Windows-Batchdateien: Eine Prozedur buendelt T-SQL-Code
   (INSERT, UPDATE, DELETE, SELECT ...) unter einem Namen und wird mit EXEC
   aufgerufen. Sie kann Parameter entgegennehmen.

 VORTEILE
   - Wiederverwendung und zentrale Logik, weniger Code im Client
   - Sicherheit: Rechte nur auf EXEC statt auf Tabellen; Schutz vor
     SQL-Injection (bei parametrisierter Verwendung)
   - Der Ausfuehrungsplan wird beim ersten Aufruf erzeugt und im Cache
     wiederverwendet (spart Kompilierzeit; nach Neustart neu erstellt)
   - Weniger Netzwerkverkehr

 WANN SIND PROZEDUREN SCHLECHT?
   - Parameter Sniffing: Der Plan wird fuer die Parameterwerte des ERSTEN
     Aufrufs erstellt und danach fuer alle weiteren genutzt. Passt der Plan
     nicht zu anderen Werten (id < 12000 = wenige Zeilen vs.
     id < 900000 = fast alle Zeilen), wird die Abfrage langsam.
   - Bedingte Zweige (IF @bit = ...) teilen sich EINEN Plan, der nur fuer
     einen Zweig optimal ist
   - Der Praefix "sp_" ist reserviert (SQL Server sucht zuerst in master)

 PRAXISTIPPS
   1. Keinen Praefix "sp_" verwenden (hier gp_ fuer "gespeicherte Prozedur")
   2. Bei stark schwankenden Datenmengen: OPTION (RECOMPILE) oder
      OPTION (OPTIMIZE FOR UNKNOWN) in der Abfrage
   3. Verzweigungen in Unterprozeduren auslagern (je Zweig ein eigener Plan)
   4. Mit SET STATISTICS IO, TIME ON messen, nicht raten
   5. SET NOCOUNT ON in Prozeduren verwenden
   6. Tatsaechlichen Ausfuehrungsplan pruefen (Index Seek vs. Scan)
==============================================================================*/

USE demoDb;
GO

DROP TABLE IF EXISTS spdemo;
DROP TABLE IF EXISTS spdemo2;
DROP PROCEDURE IF EXISTS gp_spdemo;
DROP PROCEDURE IF EXISTS gp_spdemo2;
GO

-- Testdaten aus Northwind kopieren
-- Voraussetzung: Northwind.dbo.KUNDEUMSATZ (Tabelle mit Spalte id) existiert
-- (nicht die View vKundeUmsatz aus 05_Bad View.sql)
SELECT * INTO spdemo FROM Northwind.dbo.KUNDEUMSATZ;
GO

-- Zeilenanzahl und eine Beispielzeile
SELECT TOP 1 (SELECT COUNT(*) FROM spdemo) AS Zeilen, *
FROM spdemo;
GO

CREATE NONCLUSTERED INDEX ix ON spdemo (id);
GO

SET STATISTICS IO, TIME ON;
GO

-- Ad-hoc-Abfrage
SELECT * FROM spdemo WHERE id < 12000;
GO

-- Dieselbe Abfrage als Prozedur
CREATE OR ALTER PROC gp_spdemo @par1 INT
AS
SELECT * FROM spdemo WHERE id < @par1;
GO

EXEC gp_spdemo 12000;
GO

-- So weit so gut: Prozedur vs. Ad-hoc
-- Jetzt der Gegentest: viele Zeilen. Messung vergleichen!
SELECT * FROM spdemo WHERE id < 900000;
GO

-- Prozedur nutzt den gecachten Plan (Index Seek + Lookups) = langsam
-- (Parameter Sniffing)
EXEC gp_spdemo 900000;
GO

-- Umgekehrte Reihenfolge: Plan-Cache leeren (nur auf Testsystemen!).
-- Jetzt wird der Plan fuer viele Zeilen (Scan) erstellt und passt dann
-- schlecht zum kleinen Wert
DBCC FREEPROCCACHE;
GO
EXEC gp_spdemo 900000;
EXEC gp_spdemo 12000;
GO

-- Zweites Beispiel: Zwei Zweige, ein Plan
SELECT * INTO spdemo2 FROM spdemo;
GO

CREATE NONCLUSTERED INDEX ix ON spdemo2 (id);
GO

CREATE OR ALTER PROC gp_spdemo2 @par1 INT, @bit BIT
AS
IF @bit = 0 SELECT * FROM spdemo2 WHERE id < @par1;
IF @bit = 1 SELECT * FROM spdemo2 WHERE id > @par1;
GO

-- Der erste Aufruf bestimmt den Plan fuer alle weiteren
EXEC gp_spdemo2 300000, 1;
EXEC gp_spdemo2 1000, 1;
GO
