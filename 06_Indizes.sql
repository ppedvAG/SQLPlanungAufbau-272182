/*
===============================================================================
06_Indizes.sql - Indizes in Microsoft SQL Server
===============================================================================

WAS IST EIN INDEX?
------------------
Ein Index ist eine zusätzliche Datenstruktur, mit der SQL Server Zeilen
schneller finden oder in einer benötigten Reihenfolge lesen kann. Ein Index
kostet Speicherplatz und muss bei INSERT, UPDATE und DELETE mitgepflegt werden.
Jeder zusätzliche oder zu breite Index kann Schreibvorgänge deshalb verlangsamen.

ARTEN VON INDEIZES
------------------
1. Heap
   Eine Tabelle ohne gruppierten Index (Clustered Index) ist ein Heap. Die
   Zeilen besitzen keine durch einen Index vorgegebene Schlüsselreihenfolge.
   Ein Heap ist nicht grundsätzlich schlecht, kann bei Änderungen aber
   weitergeleitete Datensätze (Forwarded Records) ansammeln.

2. Gruppierter Index (Clustered Index, CL)
   Die Blattseiten des B-Baums enthalten die Tabellendaten. Eine Tabelle kann
   höchstens einen gruppierten Index haben. Er eignet sich besonders für
   Bereichsabfragen auf seinem Schlüssel und für Zugriffe, die viele Zeilen in
   Schlüsselreihenfolge benötigen. Die logische Schlüsselreihenfolge bedeutet
   nicht, dass die Seiten auf dem Datenträger immer physisch zusammenliegen.
   Ein Primärschlüssel ist nicht automatisch gruppiert: Die Definition des
   Primärschlüssels und die Wahl des gruppierten Index sind getrennte Themen.

3. Nicht gruppierter Index (Nonclustered Index, NCL)
   Ein eigener B-Baum enthält die Schlüsselwerte und einen Zeilenverweis:
   den gruppierten Schlüssel oder bei einem Heap eine RID. Eine Tabelle kann
   mehrere nicht gruppierte Indizes haben (bis zu 999; insgesamt höchstens
   1000 Indizes pro Tabelle). Der maximale Schlüssel ist versionsabhängig:
   900 Byte für gruppierte und bis zu 1700 Byte für nicht gruppierte Indizes
   in aktuellen Versionen; außerdem sind höchstens 32 Schlüsselspalten erlaubt.

4. Eindeutiger Index (UNIQUE)
   Erzwingt die Eindeutigkeit der Schlüsselwerte und kann so Datenintegrität
   sichern. NULL-Werte und zusammengesetzte Schlüssel sind nach den SQL-Server-
   Regeln zu berücksichtigen. Ein PRIMARY KEY erzeugt ebenfalls einen
   eindeutigen Index, sofern die Integrität dies zulässt.

5. Zusammengesetzter Index
   Enthält mehrere Schlüsselspalten. Die Reihenfolge ist wichtig: Ein Index
   auf (A, B) kann typischerweise Suchen auf A sowie A und B unterstützen,
   nicht aber eine Suche nur auf B. Spalten für Gleichheitsbedingungen stehen
   häufig vor Spalten für Bereichsbedingungen; Sortierung, Joins und tatsächliche
   Abfragepläne können die passende Reihenfolge ändern.

6. Index mit eingeschlossenen Spalten (INCLUDE)
   Nicht-Schlüsselspalten liegen nur auf der Blattebene eines nicht
   gruppierten Index. Sie vergrößern den Suchbaum nicht und können einen Index
   abdeckend machen: Die Abfrage erhält alle benötigten Werte aus dem Index,
   ohne zusätzlichen Key Lookup. INCLUDE-Spalten sind keine Suchschlüssel und
   sortieren den Index nicht. Ein nicht gruppierter Index kann bis zu 1023
   eingeschlossene Spalten haben; breite Indizes erhöhen Speicher- und
   Wartungsaufwand.

7. Gefilterter Index
   Enthält nur Zeilen, die eine Filterbedingung erfüllen, zum Beispiel nur
   aktive Datensätze. Das spart Platz und Pflege, wenn die Abfragebedingung
   den Filter nachweisbar erfüllt. Filter und Abfrage müssen daher zueinander
   passen; ein gefilterter Index ist nicht automatisch besser als ein
   ungefilterter.

8. Partitionierter Index
   Verteilt einen Index über Partitionen, meist zur Verwaltung sehr großer
   Tabellen (z. B. Archivierung oder Laden nach Zeiträumen). Partitionierung
   beschleunigt Abfragen nicht automatisch. Ein ausgerichteter Index verwendet
   dieselbe Partitionsfunktion und dieselbe Partitionsspalte wie die Tabelle;
   dadurch können Partitionen gemeinsam verwaltet werden. Tabelle und Index
   müssen nicht zwingend beide partitioniert sein.

9. Columnstore-Index
   Speichert Werte spaltenorientiert und stark komprimiert. Er eignet sich
   besonders für analytische Abfragen, die viele Zeilen, aber nur wenige
   Spalten lesen. Ein gruppierter Columnstore-Index ist der primäre
   spaltenorientierte Speicher der Tabelle; ein nicht gruppierter Columnstore-
   Index ergänzt eine zeilenorientierte Tabelle. Neue Zeilen können zunächst
   in einem Delta Store liegen und später in komprimierte Rowgroups überführt
   werden. Ein Rowgroup umfasst bis zu 1.048.576 Zeilen; Bulk Loads können
   bereits ab etwa 102.400 Zeilen komprimierte Rowgroups befüllen.

10. Indizierte Sicht
    Speichert das Ergebnis einer Sicht in einem eindeutigen gruppierten Index.
    Die Sicht benötigt unter anderem WITH SCHEMABINDING und deterministische
    Ausdrücke; bei Gruppierungen ist COUNT_BIG(*) erforderlich. Es gelten
    weitere Einschränkungen. Änderungen an Basistabellen müssen auch den
    gespeicherten Sichtindex pflegen.

WELCHEN INDEX VERWENDE ICH WANN?
--------------------------------
- Zuerst Abfragen und tatsächliche Ausführungspläne untersuchen. Häufige
  Such-, Join-, Sortier- und Gruppierungsspalten sind mögliche Kandidaten.
- Bei selektiven Suchbedingungen kann ein B-Baum-Index einen SEEK ermöglichen.
  Bei vielen benötigten Zeilen kann ein SCAN günstiger sein; ein Scan ist nicht
  automatisch schlecht.
- Für wiederkehrende Bereichsabfragen kann ein sinnvoll gewählter gruppierter
  Schlüssel helfen. Die Wahl beeinflusst jedoch alle nicht gruppierten Indizes,
  da diese den gruppierten Schlüssel als Zeilenverweis enthalten.
- Nicht gruppierte Schlüssel passend zu den Suchbedingungen wählen. INCLUDE
  nur für zusätzliche Ausgabespalten verwenden, wenn dadurch ein Lookup
  vermieden wird und die Mehrkosten vertretbar sind.
- Gefilterte Indizes für häufig abgefragte Teilmengen, Columnstore für
  analytische Scans und Partitionierung primär für Datenverwaltung erwägen.
- Keine Indizes blind aus jeder Abfrage ableiten: Redundante und ungenutzte
  Indizes benötigen Speicher und verursachen Schreib- und Wartungskosten.

WARTUNG UND KONTROLLE
---------------------
- Fragmentierung, Seitendichte, Seitenzahl und Workload gemeinsam bewerten.
  REORGANIZE und REBUILD sind keine starren Prozent-Regeln; kleine Indizes
  profitieren oft nicht von einer Fragmentierungsmaßnahme. REBUILD benötigt
  mehr Ressourcen und aktualisiert üblicherweise Indexstatistiken, REORGANIZE
  aktualisiert sie nicht.
- Statistiken separat aktuell halten. Automatische Statistiken und
  sp_updatestats können helfen; Häufigkeit und Vorgehen hängen von Änderungsrate
  und Abfragequalität ab. Eine pauschale tägliche Aktualisierung ist nicht
  für jede Datenbank notwendig.
- sys.dm_db_index_usage_stats zeigt Nutzungszähler seit dem letzten Neustart
  des SQL-Server-Dienstes bzw. seit dem Zurücksetzen des Eintrags. Vor dem
  Löschen eines Indexes daher einen ausreichend repräsentativen Zeitraum und
  geplante Workloads berücksichtigen.
- Fehlende-Index-Vorschläge und der Datenbankoptimierungsratgeber sind
  Anhaltspunkte, keine fertigen Empfehlungen. Vorschläge prüfen, kombinieren
  und messen. Hypothetische Indizes des Optimierungsratgebers sind keine für
  normale Abfragen verwendbaren Indizes.
- Wartungspläne und Tools wie sp_BlitzIndex (First Responder Kit) können bei
  der Analyse unterstützen. Wartung sollte zur SQL-Server-Version und zum
  konkreten Workload passen.

VORAUSSETZUNGEN FÜR DIE BEISPIELE
---------------------------------
Die Beispiele verwenden die Übungstabelle dbo.ku aus X_Spieltabelle.sql und
gehen von einer geeigneten Northwind-Übungsdatenbank aus. Die erzeugten Tabellen
ku1, ku2 und ku3 sind Übungsobjekte. Vorhandene Übungsobjekte können mit den
gezeigten DROP TABLE-Anweisungen gelöscht und neu erstellt werden.

===============================================================================
*/

USE Northwind;
GO

SET NOCOUNT ON;
GO

----------------------------------------------------------------------------
-- 1. Heap, Forwarded Records und gruppierter Index
----------------------------------------------------------------------------

-- Voraussetzung: dbo.ku existiert. ku2 wird hier bewusst als Heap angelegt.
DROP TABLE IF EXISTS dbo.ku2;
SELECT *
INTO dbo.ku2
FROM dbo.ku;
GO

-- Die Identitätsspalte wird nachträglich ergänzt. In einem Heap können dabei
-- weitergeleitete Datensätze entstehen; die genaue Anzahl ist datenabhängig.
ALTER TABLE dbo.ku2
ADD id INT IDENTITY(1, 1);
GO

-- Alte Diagnosefunktion; die DMV ist für neue Analysen vorzuziehen.
DBCC SHOWCONTIG ('dbo.ku2');
GO

SELECT
    index_id,
    page_count,
    avg_page_space_used_in_percent,
    avg_fragmentation_in_percent,
    fragment_count
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    OBJECT_ID(N'dbo.ku2'),
    NULL,
    NULL,
    N'DETAILED'
);
GO

-- Ein gruppierter Index ordnet die Zeilen logisch nach id und beseitigt
-- Forwarded Records des Heaps.
CREATE UNIQUE CLUSTERED INDEX CX_ku2_id
    ON dbo.ku2 (id);
GO

----------------------------------------------------------------------------
-- 2. Nicht gruppierter Index, Lookup und abdeckender Index
----------------------------------------------------------------------------

-- Neu aus der Quelle aufbauen, damit die Übung reproduzierbar ist.
DROP TABLE IF EXISTS dbo.ku1;
SELECT *
INTO dbo.ku1
FROM dbo.ku;
GO

-- X_Spieltabelle.sql kann eine ID-Spalte anlegen. Nur ergänzen, falls sie fehlt.
IF COL_LENGTH(N'dbo.ku1', N'id') IS NULL
BEGIN
    ALTER TABLE dbo.ku1
    ADD id INT IDENTITY(1, 1);
END;
GO

-- Baseline messen. Ohne passenden Index ist ein Scan wahrscheinlich.
SET STATISTICS IO, TIME ON;

SELECT id
FROM dbo.ku1
WHERE id = 100;
GO

-- Ein nicht gruppierter Index ermöglicht bei einer selektiven Suche einen
-- Seek. Bei einem Heap kann der Zugriff zusätzlich die RID verwenden.
CREATE NONCLUSTERED INDEX IX_ku1_id
    ON dbo.ku1 (id);
GO

SELECT id
FROM dbo.ku1
WHERE id = 100;
GO

-- Freight ist im Index nicht enthalten: SQL Server kann einen Key Lookup
-- benötigen. Bei vielen Treffern kann ein Scan trotzdem günstiger sein.
SELECT id, freight
FROM dbo.ku1
WHERE id = 100;
GO

SELECT id, freight
FROM dbo.ku1
WHERE id < 10500;
GO

-- INCLUDE deckt die Abfrage ab. Das kann Lookups vermeiden, vergrößert aber
-- den Index und erhöht dessen Pflegekosten.
CREATE NONCLUSTERED INDEX IX_ku1_id_include_freight
    ON dbo.ku1 (id)
    INCLUDE (freight);
GO

SELECT id, freight
FROM dbo.ku1
WHERE id < 900500;
GO

----------------------------------------------------------------------------
-- 3. Zusammengesetzte und gefilterte Indizes
----------------------------------------------------------------------------

-- Gleichheitsbedingung auf country, danach Bereichsbedingung auf freight.
CREATE NONCLUSTERED INDEX IX_ku1_country_freight
    ON dbo.ku1 (country, freight);
GO

SELECT *
FROM dbo.ku1
WHERE country = N'USA'
  AND freight < 1;
GO

-- Für eine Teilmenge kann ein gefilterter Index kleiner als ein vollständiger
-- Index sein. Die Abfrage muss den Filter des Indexes erfüllen.
CREATE NONCLUSTERED INDEX IX_ku1_country_freight_usa
    ON dbo.ku1 (freight)
    WHERE country = N'USA';
GO

SELECT *
FROM dbo.ku1
WHERE country = N'USA'
  AND freight < 1;
GO

----------------------------------------------------------------------------
-- 4. Abdeckende Indizes für Gruppierung und Joins
----------------------------------------------------------------------------

-- Suchspalte als Schlüssel, benötigte Gruppierungs- und Rechenspalten als
-- INCLUDE-Spalten. Mit den tatsächlichen Plänen und Messwerten vergleichen.
CREATE NONCLUSTERED INDEX IX_ku1_employee_cover
    ON dbo.ku1 (employeeid)
    INCLUDE (country, city, unitprice, quantity);
GO

SELECT
    country,
    city,
    SUM(unitprice * quantity) AS Umsatz
FROM dbo.ku1
WHERE employeeid = 2
GROUP BY country, city;
GO

CREATE NONCLUSTERED INDEX IX_ku1_employee_shipcountry_cover
    ON dbo.ku1 (employeeid, shipcountry)
    INCLUDE (companyname, lastname, productname);
GO

SELECT companyname, lastname, productname
FROM dbo.ku1
WHERE employeeid = 2
  AND shipcountry = N'USA';
GO

-- Bei OR kann kein einzelner zusammengesetzter Index beide Suchpfade so
-- bedienen wie bei AND. Der Optimierer kann mehrere Zugriffswege kombinieren.
SELECT companyname, lastname, productname
FROM dbo.ku1
WHERE employeeid = 2
   OR shipcountry = N'USA';
GO

----------------------------------------------------------------------------
-- 5. Indizierte Sicht
----------------------------------------------------------------------------

CREATE OR ALTER VIEW dbo.vdemo
WITH SCHEMABINDING
AS
    SELECT country, COUNT_BIG(*) AS Anzahl
    FROM dbo.ku1
    GROUP BY country;
GO

-- Die indizierte Sicht benötigt zuerst einen eindeutigen gruppierten Index.
CREATE UNIQUE CLUSTERED INDEX CIX_vdemo_country
    ON dbo.vdemo (country);
GO

SELECT country, Anzahl
FROM dbo.vdemo;
GO

-- Vergleichsabfrage ohne indizierte Sicht.
SELECT country, COUNT_BIG(*) AS Anzahl
FROM dbo.ku1
GROUP BY country;
GO

----------------------------------------------------------------------------
-- 6. Columnstore-Index
----------------------------------------------------------------------------

-- Columnstore ist besonders für analytische Abfragen mit vielen Zeilen und
-- wenigen benötigten Spalten geeignet. Eine reine Kopie ist zunächst Heap.
DROP TABLE IF EXISTS dbo.ku3;
SELECT *
INTO dbo.ku3
FROM dbo.ku;
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_ku3
    ON dbo.ku3;
GO

SELECT
    companyname,
    AVG(quantity) AS Durchschnitt,
    MIN(quantity) AS Minimum
FROM dbo.ku3
WHERE country = N'Germany'
GROUP BY companyname;
GO

SELECT
    companyname,
    AVG(quantity) AS Durchschnitt,
    MIN(quantity) AS Minimum
FROM dbo.ku3
WHERE city = N'Berlin'
GROUP BY companyname;
GO

-- Speicherbedarf vor und nach der Columnstore-Komprimierung vergleichen.
EXEC sys.sp_spaceused N'dbo.ku';
EXEC sys.sp_spaceused N'dbo.ku3';
GO

----------------------------------------------------------------------------
-- 7. Ausführungspläne, Nutzung und Wartung
----------------------------------------------------------------------------

-- STATISTICS IO/TIME und der tatsächliche Ausführungsplan helfen beim Messen.
-- Ein Index Scan kann besser als ein Table Scan sein; ein Seek ist nicht
-- grundsätzlich besser, wenn dafür sehr viele Zeilen gelesen werden.
SET STATISTICS IO, TIME OFF;
GO

-- Nutzungszähler nach Datenbank und Index. Fehlende Einträge können auch
-- bedeuten, dass der Dienst seitdem neu gestartet oder der Index neu erstellt
-- wurde. Vor dem Löschen eines Indexes einen repräsentativen Zeitraum prüfen.
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
    OBJECT_NAME(i.object_id) AS Tabellenname,
    i.name AS Indexname,
    i.index_id,
    COALESCE(u.user_seeks, 0) AS user_seeks,
    COALESCE(u.user_scans, 0) AS user_scans,
    COALESCE(u.user_lookups, 0) AS user_lookups,
    COALESCE(u.user_updates, 0) AS user_updates
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS u
    ON u.database_id = DB_ID()
   AND u.object_id = i.object_id
   AND u.index_id = i.index_id
WHERE i.object_id > 0
  AND i.index_id > 0
ORDER BY
    user_seeks DESC,
    user_scans DESC;
GO

-- Fragmentierung und Seitendichte sind nur im Kontext der Seitanzahl und
-- Workload zu bewerten. REORGANIZE/REBUILD nicht pauschal nach Prozentwerten
-- ausführen; anschließend ggf. Statistiken aktualisieren.
SELECT
    OBJECT_SCHEMA_NAME(ps.object_id) AS SchemaName,
    OBJECT_NAME(ps.object_id) AS Tabellenname,
    i.name AS Indexname,
    ps.page_count,
    ps.avg_fragmentation_in_percent,
    ps.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    N'SAMPLED'
) AS ps
INNER JOIN sys.indexes AS i
    ON i.object_id = ps.object_id
   AND i.index_id = ps.index_id
WHERE ps.database_id = DB_ID()
  AND ps.index_id > 0
ORDER BY ps.page_count DESC;
GO

-- Aktualisiert Statistiken für Tabellen in der aktuellen Datenbank.
-- Es ersetzt keine Prüfung der Aktualität und ist nicht zwingend täglich nötig.
EXEC sys.sp_updatestats;
GO
