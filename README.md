# SQL Server – Planung, Aufbau und Verwaltung

- Kursrepository der ppedv AG zu Planung, Installation und Betrieb von SQL Server.

## Unterlagen

- `01_Virtualisierung.txt`: SQL Server in virtualisierten Umgebungen
- `02_Setup.txt`: Installation und Grundeinstellungen
- `03_Databases.txt`: Planung und Betrieb von Datenbanken
- `04_Seiten.sql`: Seiten und Extents, Speicherverwaltung und Datenzugriffe
- `04__forward_record_Count.sql`: Forwarded Records in Heaps und deren Diagnose
- `05_Bad View.sql`: Sichten, Vorteile und typische Fallstricke
- `06_Indizes.sql`: Indexarten, Ausführungspläne, Nutzung und Wartung
- `07_Bad Procedure.sql`: Gespeicherte Prozeduren und Parameter Sniffing

## Ergänzende SQL-Skripte

- `X_DB_InstNwind.sql`: Erstellt die Northwind-Beispieldatenbank mit Tabellen,
  Beispieldaten und weiteren Objekten.
- `X_Spieltabelle.sql`: Erstellt die Übungstabelle `KU` und eine erste Kopie
  (`KU1`) für die Beispiele zu Indizes und Forwarded Records.
- `X_DiagnosticView2025.sql`: Diagnoseabfragen für SQL Server 2025. Das Skript
  prüft, ob die Instanz die erwartete Hauptversion verwendet.

## Hinweise zur Ausführung

- SQL-Skripte setzen je nach Beispiel eine Northwind-Datenbank oder weitere
  Übungsobjekte voraus. Beachten Sie die Voraussetzungen in den Kommentaren
  des jeweiligen Skripts.
- `07_Bad Procedure.sql` verwendet `demoDb` sowie
  `Northwind.dbo.KUNDEUMSATZ`. Es leert außerdem den Prozedurcache; führen Sie
  das Skript daher nur auf einem geeigneten Testsystem aus.
- Die Hinweise dienen als Orientierung. Konkrete Einstellungen richten sich
  nach SQL-Server-Version, Workload und Umgebung.
