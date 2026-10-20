/*
=====================================================================
 Seiten.sql - Seiten (Pages) und Blöcke (Extents) im SQL Server
=====================================================================

1. SEITEN (PAGES)
-----------------
- Kleinste Speichereinheit für Daten in SQL Server: 8192 Bytes (8 KB).
- Aufbau: 96 Byte Seitenkopf (Header) + Datenbereich + Zeilen-Offset-Array
  am Seitenende (2 Byte pro Zeile).
- Maximale Nutzlast für Zeilen: 8060 Bytes pro Zeile (8192 - Header - Overhead).
- Limits:
    * Eine Zeile muss (bei Standard-Datentypen) komplett auf EINE Seite passen
      -> max. 8060 Bytes. Ausnahme: Zeilenüberlauf (ROW_OVERFLOW_DATA) bei
      varchar/nvarchar/varbinary/sql_variant, und LOB_DATA bei (max)-Typen,
      text, image, xml. Dann liegen Teile auf eigenen Seiten.
    * Max. 8 Zeilen sind NICHT das Limit; es hängt nur von der Zeilengröße ab
      (max. ca. 8096 Zeilen pro Seite bei sehr kleinen Zeilen).
    * Eine Zeile wird NIE auf zwei Seiten verteilt (Datenseite) -> Verschnitt!
      Beispiel: 2 x 4100 Bytes = 8200 > 8060 -> nur 1 Zeile pro Seite,
      ca. 50% der Seite bleiben leer.
- Seitentypen: Datenseite, Indexseite, LOB-/Row-Overflow-Seite,
  GAM, SGAM, PFS (Zuordnungs-/Verwaltungsseiten), IAM, Boot-/Dateiheader.

2. BLÖCKE (EXTENTS)
-------------------
- 1 Block = 8 aufeinanderfolgende Seiten = 64 KB.
- Ein Block ist die Einheit der Platzzuweisung auf der Platte.
- Gemischte Blöcke (mixed extents): Seiten gehören bis zu 8 Objekten.
  Einheitliche Blöcke (uniform extents): gehören einem Objekt.
  Seit SQL Server 2016 sind standardmäßig (außer tempdb/model-Einstellung)
  alle Blöcke uniform (Trace Flag 1118 ist Standardverhalten;
  MIXED_PAGE_ALLOCATION steuert das pro Datenbank).
- Limit: Eine Datei besteht aus Blöcken; Dateigröße ist ein Vielfaches von 64 KB.
  Die Seitenanzahl pro Datei ist über eine 4-Byte-Seitennummer adressiert
  (max. 16 TB pro Datei).

3. WAS PASSIERT BEI INSERT, UPDATE, DELETE?
-------------------------------------------
INSERT
  - SQL Server sucht (über PFS/GAM/IAM) eine Seite mit genug freiem Platz.
    Bei einem Heap: irgendeine Seite mit Platz; bei Clustered Index: die Seite,
    in die der Schlüssel logisch gehört.
  - Ist keine Seite frei, wird eine neue Seite (ggf. ein neuer Block)
    zugewiesen.
  - Passt die Zeile nicht mehr in die Seite (Clustered Index) -> PAGE SPLIT:
    ca. die Hälfte der Zeilen wandert auf eine neue Seite (Fragmentierung,
    zusätzliche Logs).
  - Die Änderung erfolgt zuerst im RAM (Buffer Pool) und im Transaktionsprotokoll
    (Write-Ahead-Logging). Erst später schreibt der Checkpoint / Lazy Writer
    die "dirty pages" in die Datendatei.

UPDATE
  - Gleiche Größe / kleiner: Änderung "in place" auf der Seite.
  - Größere Zeile (z.B. varchar wächst): passt sie nicht mehr -> Page Split
    (Index) bzw. Forwarded Record (Heap: Zeile wird verschoben, am alten
    Platz bleibt ein Weiterleitungszeiger).
  - Bei Zeilenversionierung (RCSI/Snapshot) kommen 14 Bytes pro Zeile
    für Versionsinformationen dazu; die Versionen liegen in tempdb (PVS bei ADR).

DELETE
  - Zeile wird nur als "gelöscht" markiert (Ghost Record) und später vom
    Ghost-Cleanup-Task physisch entfernt.
  - Der Platz in der Seite wird erst dann wiederverwendet.
  - Eine komplett leere Seite wird im Index freigegeben; bei Heaps nur mit
    TABLOCK-Hinweis (oder Rebuild) zuverlässig -> Heaps können "leere" Seiten
    behalten.
  - Die Datendatei wird dadurch NICHT kleiner (nur SHRINK, was stark
    fragmentiert und nicht empfohlen ist).

4. ZUGRIFF: KOMMEN SEITEN IN DEN RAM?
-------------------------------------
- JA. SQL Server liest und schreibt NIE direkt auf Zeilenebene von der Platte.
  Jede benötigte Seite wird zuerst vom Datenträger in den BUFFER POOL (RAM)
  geladen (Physical Read) und von dort gelesen (Logical Read).
- Ist die Seite schon im RAM -> kein Plattenzugriff (Cache Hit).
- Änderungen passieren nur im RAM (dirty page); Checkpoint / Lazy Writer
  / Eager Writer schreiben später auf die Platte.
- Read-Ahead: Beim Scan werden Seiten im Voraus geladen (bis zu 64 Seiten /
  1 Block pro Request, Enterprise noch mehr).
- Der RAM ist begrenzt (max server memory). Reicht er nicht, werden selten
  genutzte Seiten verdrängt (LRU-K-ähnlicher Algorithmus,
  Page Life Expectancy sinkt).
- Daher: Weniger Seiten = weniger I/O = weniger RAM = weniger CPU.
  Die Seiten liegen im RAM genauso groß wie auf der Platte (8 KB),
  auch leerer Platz auf der Seite belegt RAM!

5. PROBLEME BEI SEITEN UND BLÖCKEN
----------------------------------
a) Schlechte Seitendichte (Verschnitt)
   - Zu breite Zeilen (z.B. char(4100)) -> nur eine Zeile je Seite
     -> ~50% Platzverlust im Storage UND im RAM.
   - Lösung: Datentypen verkleinern, varchar statt char, Normalisierung,
     Kompression (ROW/PAGE), passende Fill Factor-Einstellung.

b) Fragmentierung
   - Interne: freier Platz in den Seiten (Page Splits, Deletes).
   - Externe: logische Reihenfolge der Seiten ≠ physische Reihenfolge
     -> schlechter Read-Ahead.
   - Lösung: REORGANIZE / REBUILD, sinnvolle Clustered Keys (aufsteigend,
     z.B. IDENTITY), Fill Factor.

c) Page Splits
   - Teuer (neue Seite, Logging, Sperren). Zufällige GUIDs als Clustered Key
     verursachen sehr viele Splits.

d) Forwarded Records bei Heaps
   - Jeder Zugriff braucht 2 Seitenzugriffe. Lösung: Clustered Index oder
     ALTER TABLE ... REBUILD.

e) LATCHES und Contention
   - Latch = leichtgewichtige, kurzzeitige Sperre (Synchronisation) auf
     interne Strukturen im RAM, z.B. auf eine Seite im Buffer Pool.
     Sie schützt die physische Konsistenz der Seite (nicht die logischen Daten
     wie ein Lock) und wird nicht bis zum Transaktionsende gehalten.
   - Latch-Typen: PAGELATCH_* (Seite im RAM, z.B. PAGELATCH_EX bei Insert),
     PAGEIOLATCH_* (Seite wird gerade von der Platte gelesen -> I/O-Wartezeit),
     LATCH_* (andere interne Strukturen).
   - Modi: SH (Shared), UP (Update), EX (Exclusive), KP (Keep), DT (Destroy).
   - Typisches Problem: "Last Page Insert Contention". Bei einem aufsteigenden
     Clustered Key (IDENTITY) wollen viele Sessions gleichzeitig in die
     LETZTE Seite schreiben -> PAGELATCH_EX-Wartezeiten.
     Lösungen: OPTIMIZE_FOR_SEQUENTIAL_KEY = ON (ab SQL 2019), Hash-
     Partitionierung / Schlüssel mit Präfix, In-Memory OLTP.
   - Tempdb-Contention auf Allokationsseiten (PFS, GAM, SGAM):
     Viele Sessions legen gleichzeitig temporäre Objekte an.
     Lösung: mehrere gleich große tempdb-Dateien (Faustregel: 1 pro Kern,
     max. 8 zunächst), Memory-Optimized tempdb Metadata.
   - PAGEIOLATCH-Waits: zu wenig RAM oder zu langsame Platte,
     zu viele Scans -> Indizes, mehr RAM, Kompression.
   - Latches vs. Locks: Locks schützen logische Konsistenz (Transaktionen,
     Isolation), Latches die interne Speicherstruktur; Latches haben keine
     Deadlock-Erkennung, sind aber sehr kurz. Spinlocks sind noch
     leichtgewichtiger (CPU-Schleife statt Warten).

f) Torn Pages / Korruption
   - Eine 8-KB-Seite wird als 16 Sektoren à 512 Byte geschrieben. Bricht
     der Schreibvorgang ab -> "Torn Page". PAGE_VERIFY CHECKSUM erkennt
     das (Standard, nicht TORN_PAGE_DETECTION oder NONE verwenden).
     DBCC CHECKDB prüft Seiten.

g) Autogrowth / Blöcke
   - Kleine Wachstumsschritte -> viele Wachstumsvorgänge und Fragmentierung
     der Datei. Besser: feste, größere Schritte (z.B. 256 MB+),
     Instant File Initialization für Datendateien.

6. NÜTZLICHE WERKZEUGE
----------------------
  DBCC SHOWCONTIG, sys.dm_db_index_physical_stats, DBCC IND / DBCC PAGE,
  sys.dm_os_buffer_descriptors, sys.dm_os_wait_stats,
  sys.dm_os_latch_stats, SET STATISTICS IO, TIME ON.
=====================================================================
*/


-----------------------------------------------------------------------
-- Test: Tabelle mit char(4100)
-- Einfügen von 20000 Datensätzen
-----------------------------------------------------------------------

CREATE TABLE t1
(
    id  INT IDENTITY,
    spx CHAR(4100)
);
GO

INSERT INTO t1
SELECT 'XY';
GO 20000 -- Laufzeit je nach System: ca. 20 Sek. bis 1:45 Min.


/*
Idee:

Wie groß ist ein Datensatz? ca. 4 KB
    SELECT 20000 * 4  --> 80 MB erwartet,
    aber die Tabelle t1 ist tatsächlich 160 MB groß!

Datensätze liegen in Datendateien (.mdf).
Dateien sind in Seiten und Blöcken organisiert.
Eine Seite hat immer 8192 Bytes, davon sind nur 8060 Bytes Nutzlast.
Zwei Datensätze à 4100 Bytes passen nicht auf eine Seite
-> je Seite nur 1 Datensatz -> 20000 Seiten * 8 KB = 160 MB.
*/


-- Weitere Beispieltabelle (Vergleich varchar / char)
CREATE TABLE t2
(
    id  INT IDENTITY,
    sp1 VARCHAR(4100),
    sp2 CHAR(4100)
);
GO

-- Großes Ziel: Reduzieren der Seiten!
-- Weniger Seiten --> weniger CPU --> weniger RAM
-- Mittel dazu:
--   * Indizes
--   * Kompression
--   * Partitionierung


-- Seitenanzahl und Dichte der Tabelle prüfen
DBCC SHOWCONTIG('t1');
--- Gescannte Seiten..............: 20000
--- Mittlere Seitendichte (voll)..: 50.79 %
--- Gescannte Blöcke..............: 2501

-- Besser (und aktuell empfohlen): DMV
SELECT index_id, page_count, avg_page_space_used_in_percent, fragment_count
FROM   sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('t1'), NULL, NULL, 'DETAILED');


-- Typische Kandidaten für Seitenverschwendung:
-- Tabellen mit vielen Spalten und vielen Zeilen,
-- z.B. Hobby1 Hobby2 Hobby3 Fax1 Fax2 Fax3 Frau1 Frau2 Frau3 Frau4 Religion

-- ACHTUNG: DBCC SHOWCONTIG ohne Parameter untersucht ALLE Tabellen!
-- Nur sehr vorsichtig einsetzen (hohe Last).
-- DBCC SHOWCONTIG();


-----------------------------------------------------------------------
-- Wie hätte man das besser machen können?
-----------------------------------------------------------------------
-- Tabelle neu anlegen (vorher ggf. DROP TABLE t1):
-- CREATE TABLE t1 (id INT IDENTITY, spx CHAR(4100));
-- GO

-- Möglichkeiten:
--   * Datentyp ändern: statt CHAR lieber VARCHAR
--       (evtl. funktioniert die Anwendung danach nicht mehr!)
--   * statt CHAR(4100) lieber CHAR(4030), dann passen 2 Zeilen auf eine Seite
--   * Die Anwendung muss weiterlaufen!
--   * Tabelle komprimieren: Die Anwendung "sieht" weiterhin 160 MB,
--     auf dem Server wird aber weniger gelesen/geschrieben
--     (Festplatte UND RAM sind komprimiert).
--     Kostet CPU - meist ist hier noch genug übrig.
--     Normalerweise schafft man 40 bis 60 % Ersparnis.

-- Kompression abschätzen und aktivieren
EXEC sp_estimate_data_compression_savings 'dbo', 't1', NULL, NULL, 'PAGE';

ALTER TABLE t1 REBUILD WITH (DATA_COMPRESSION = PAGE);
GO


-- Ergebnis messen
SET STATISTICS IO, TIME ON;

SELECT * FROM t1; -- statt 20000 Seiten nun nur noch ca. 32 Seiten (aus dem RAM)

-- Typische Einsatzgebiete: SAP, AX, SharePoint
