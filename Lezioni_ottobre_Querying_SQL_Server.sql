/**************************
VISTE INDICIZZATE
**************************/
/*Tenere bene a mente questo LINK, soprattutto le limitazioni
sulle opzioni SET che, se non rispettate, possono compromettere
il funzionamento del Database!!
https://learn.microsoft.com/it-it/sql/relational-databases/views/create-indexed-views?view=sql-server-ver16

Questo vale anche per indici su colonne calcolate e indici filtrati
Ricorda: le opzioni SET dipendono anche dalla connessione!
*/


--creiamo una vista con l'opzione schemabinding
CREATE VIEW dbo.MyView 
WITH SCHEMABINDING
AS 
SELECT YEAR(F.DataFattura) AS Anno, 
	SUM(ISNULL(FP.PrezzoUnitario,0)*ISNULL(FP.Quantita,0)) AS ImportoTotale,
	COUNT_BIG(*) AS Numero
FROM  dbo.Fatture AS F
INNER JOIN dbo.FattureProdotti AS Fp
	ON F.IdFattura = Fp.IdFattura
GROUP BY YEAR(F.DataFattura);

--La vista non occupa spazio!
EXEC sp_spaceused N'dbo.MyView';


--Analizziamo i piani d'esecuzione del codice di inserimento e aggiornamento
INSERT INTO CorsoSQL.dbo.FattureProdotti(IdFattura, IdProdotto,
	PrezzoUnitario, Quantita, Sconto, Omaggio, Iva)
VALUES (1,6,10,28,0,0,0);

UPDATE CorsoSQL.dbo.Fatture
SET    DataFattura = '20240101'
WHERE  IdFattura = 1;

--l'opzione schemabinding mi impedisce di modificare le colonne coinvolte
ALTER TABLE CorsoSQL.dbo.Fatture ALTER COLUMN DataFattura DATETIME NOT NULL;

--creiamo un clustered index univoco sulla vista
CREATE UNIQUE CLUSTERED INDEX Ix_anno ON CorsoSQL.dbo.MyView(Anno);

--la vista ora occupa spazio!
EXEC sp_spaceused N'dbo.MyView';

/*Analizziamo nuovamente i piani d'esecuzione del codice
di inserimento e aggiornamento. Sql Server aggiorna anche la vista MyView! */
INSERT INTO CorsoSQL.dbo.FattureProdotti(IdFattura, IdProdotto,
	PrezzoUnitario, Quantita, Sconto, Omaggio, Iva)
VALUES (1,8,10,28,0,0,0);

UPDATE CorsoSQL.dbo.Fatture
SET    DataFattura = '20240101'
WHERE  IdFattura = 1;

/*Eseguiamo sull'edizione Express questa query. Non cambia niente.
Sulla versione Enterprise, SQL Server valuterà se usare o meno la
vista materializzata*/
SELECT *
FROM   dbo.MyView; 

/*Su altre versioni posso forzare l'utilizzo della vista materializzata tramite l'HINT no expand*/
SELECT *
FROM   dbo.MyView (noexpand);

/*Questo vale anche per query più complesse di una semplice SELECT */
SELECT SUM(ImportoTotale) 
FROM MyView (noexpand) as a;

/*Sulla versione Enterprise e su Azure verrà valutato se usare una vista materializzata
anche quando eseguiamo il codice originale della vista (o altro codice simile)*/
SELECT YEAR(F.DataFattura) AS Anno, 
	SUM(ISNULL(FP.PrezzoUnitario,0)*ISNULL(FP.Quantita,0)) AS ImportoTotale,
	COUNT_BIG(*) AS Numero
FROM  dbo.Fatture AS F 
INNER JOIN dbo.FattureProdotti AS Fp
	ON F.IdFattura = Fp.IdFattura
GROUP BY YEAR(F.DataFattura);

/***************
ATTENZIONE!
***************/
/*Con opzioni SET diverse da quelle standard, 
usare la vista indicizzata restituisce un errore*/

SET CONCAT_NULL_YIELDS_NULL ON

SELECT * FROM dbo.MyView (noexpand); 


/******************************************
LA DEFINZIONE DELLE VISTE CON SELECT * 
NEL CODICE NON SI AGGIORNA IN AUTOMATICO 
*******************************************/

/*Creiamo una vista con SELECT * nel codice. */
CREATE VIEW dbo.Clienti_v AS
SELECT *
FROM   dbo.CLIENTI;

/*Dobbiamo essere consapevoli che se aggiungiamo una colonna alla
tabella sottostante, essa non sarà visibile automaticamente nella vista*/
ALTER TABLE CorsoSQL.dbo.Clienti ADD NewColumn INT;

/*La colonna NewColumn non è visibile*/
SELECT *
FROM   dbo.Clienti_v;


/***************
VISTE E UPDATE
***************/
CREATE VIEW query.v_Clienti AS
SELECT *
FROM   query.Clienti
WHERE  IdCliente > 5;

/*Questo codice funziona! Non sto inserendo i dati nella vista 
(non ha senso come affermazione). Sto inserendo i dati
nella tabella sottostante la vista, per via del particolare codice*/ 
INSERT INTO CorsoSQL.query.v_Clienti(IdCliente, Nome, Cognome, DataNascita, RegioneResidenza)
VALUES (11,'NicolaVista','Vista',null,null);

/*Anche questo codice funziona nonostante inserisco un valore che non rispetta 
il filtro nella vista*/
INSERT INTO CorsoSQL.query.v_Clienti(IdCliente, Nome, Cognome, DataNascita, RegioneResidenza)
VALUES (-1,'NicolaVista','Vista',null,null);


/*Ricreiamo la vista con l'opzione WITH CHECK OPTION*/
ALTER VIEW query.v_Clienti AS
SELECT *
FROM   query.Clienti
WHERE  IdCliente > 5
WITH CHECK OPTION;

/*Ora non posso inserire tramite la vista dei 
dati che non rispettano il filtro*/
INSERT INTO CorsoSQL.query.v_Clienti(IdCliente, Nome, Cognome, DataNascita, RegioneResidenza)
VALUES (-1,'NicolaVista','Vista',null,null);

/*Ricreo la vista senza l'opzione*/
ALTER VIEW query.v_Clienti AS
SELECT *
FROM   query.Clienti
WHERE  IdCliente > 5;


/***************
COMPUTED COLUMNS
***************/
/*
Leggere bene la documentazione
https://learn.microsoft.com/en-us/sql/relational-databases/tables/specify-computed-columns-in-a-table?view=sql-server-ver17
https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns?view=sql-server-ver17
*/

/*Aggiungiamo due colonne calcolate, una non persisted, l'altra persisted*/
ALTER TABLE CorsoSQL.query.Clienti 
ADD Denominazione AS Concat(Nome,' ',Cognome);

ALTER TABLE CorsoSQL.query.Clienti 
ADD MeseDataNascita AS MONTH(DataNascita) PERSISTED;

/*Dal piano d'esecuzione vediamo che la colonna non persisted deve essere calcolata*/
SELECT * 
FROM   query.Clienti;

/*Dal piano d'esecuzione vediamo che la colonna persisted deve essere inserita*/
INSERT INTO CorsoSQL.query.Clienti (IdCliente, Nome, Cognome, DataNascita, RegioneResidenza)
VALUES (12,'Nicola','Iantomasi',null,null);


/*Se proviamo a specificare noi il valore da inserire otterremo un errore*/
INSERT INTO CorsoSQL.query.Clienti (IdCliente, Nome, Cognome, DataNascita, RegioneResidenza, MeseDataNascita)
VALUES (12,'Nicola','Iantomasi',null,null,null);

/*Facendo molta attenzione alla documentazione, soprattutto per 
quel che riguarda le opzioni SET, posso creare un indice su una 
colonna calcolata.
Ricorda: le opzioni SET dipendono anche dalla connessione!*/
CREATE INDEX IX_Mese on CorsoSQL.query.Clienti(MeseDataNascita);

/*Questa query esegue un Index Seek*/
SELECT COUNT(*)
FROM   query.Clienti
WHERE  MeseDataNascita = 1;

/*Anche questa esegue un Index Seek*/
SELECT COUNT(*)
FROM   query.Clienti
WHERE  MONTH(DataNascita) = 1;

/****************
FUNZIONI CUSTOM
****************/
/*Vediamo come l'utilizzo di una funzione custom UDF
può impedire il parallelismo*/

CREATE or alter FUNCTION dbo.Test(@input int)
RETURNS DECIMAL(18,2)
AS
BEGIN
DECLARE @Valore DECIMAL(18,2)

IF @input > 0
	set @Valore = (SELECT MAX(@input) FROM dbo.Fatture WHERE IDFATTURA = @INPUT) * 2

RETURN @Valore
END

/*Eseguiamo questa query*/
SELECT *, DBO.Test(IdFattura)
FROM   dbo.Fatture as f
ORDER BY DataPagamento

/*Solo nelle ultime versioni SQL Server riesce a parallelizzare
alcune funzioni, ad esempio se in precedenza togliamo 
il MAX, la funzione viene parallelizzata. */

/*Le funzioni possono restituire anche tabelle. Tuttavia
stiamo deviando dall'utilizzo standard e più performante di SQL Server*/
CREATE FUNCTION query.GetFattureByRegione
(
    @Regione VARCHAR(100),
    @SoloGrandi BIT
)
RETURNS @Result TABLE
(
    IdFattura INT,
    NomeCliente VARCHAR(100),
    Regione VARCHAR(100),
    Spedizione DECIMAL(10,2),
    DataFattura DATE
)
AS
BEGIN
    IF (@SoloGrandi = 1)
    BEGIN
        INSERT INTO @Result(IdFattura,NomeCliente,Regione,Spedizione,DataFattura)
        SELECT f.IdFattura, c.Nome, c.Regione, f.Spedizione, f.DataFattura
        FROM dbo.Fatture f
        INNER JOIN dbo.Clienti c ON f.IdCliente = c.IdCliente
        WHERE c.Regione = @Regione
          AND f.Spedizione > 1;
    END
    ELSE
    BEGIN
        INSERT INTO @Result(IdFattura,NomeCliente,Regione,Spedizione,DataFattura)
        SELECT f.IdFattura, c.Nome, c.Regione, f.Spedizione, f.DataFattura
        FROM dbo.Fatture f
        INNER JOIN dbo.Clienti c ON f.IdCliente = c.IdCliente
        WHERE c.Regione = @Regione
    END

    RETURN;
END;

/*Esempio di utilizzo*/
SELECT a.*
FROM dbo.GetFattureByRegione('Lombardia', 0) as a
INNER JOIN dbo.fatture as f
    on a.idfattura = f.idfattura;

/*Questa invece è una funzione tabellare INLINE (vista parametrica)*/
CREATE FUNCTION query.VistaRicerca (@ParNome as varchar(50))
RETURNS TABLE 
AS RETURN
SELECT * 
FROM   query.Clienti 
WHERE  Nome = @ParNome;


/***************
TRIGGER
***************/
/*Non usare trigger se non strettamente necessario...fine :-) */

SELECT *
FROM   query.Clienti
WHERE  IdCliente IN (1,2,3);

/*Creiamo un trigger
sulla tabella query.clienti
che DOPO
una INSERT, una UPDATE o una DELETE
fa delle cose */
CREATE TRIGGER trg_Clienti
ON CorsoSQL.query.Clienti
AFTER INSERT,UPDATE,DELETE 
AS
BEGIN
    print 'trg_Clienti';

    SELECT * FROM inserted;
    SELECT * FROM deleted;
END;

UPDATE CorsoSQL.query.Clienti
SET    Nome = 'Raffaele'
WHERE  IdCliente IN (1,2,3);

/*I trigger possono essere disabilitati e abilitati*/
DISABLE TRIGGER trg_Clienti
ON CorsoSQL.query.Clienti;

ENABLE TRIGGER trg_Clienti
ON CorsoSQL.query.Clienti;


/*Creiamo un nuovo trigger*/
CREATE TRIGGER trg_after_insert_clienti
ON CorsoSQL.query.Clienti
AFTER INSERT 
AS
BEGIN
    print 'trg_after_insert_clienti';

    UPDATE CorsoSQL.query.Clienti
    SET    Nome = Concat(Nome,'T')
    WHERE  IdCliente IN (SELECT IdCliente FROM Inserted);

    UPDATE CorsoSQL.query.Fatture
    SET    Importo = Importo + 1;
END;

/*Eseguiamo l'UPDATE, scatta solo il primo trigger*/
UPDATE CorsoSQL.query.Clienti
SET    Nome = 'Raffaele'
WHERE  IdCliente IN (1,2,3);

/*Eseguiamo l'INSERT. Cosa scatta?*/
INSERT INTO CorsoSQL.query.Clienti
VALUES (-1,'Nicola','Iantomasi',null,null);

/*
Non si riesce a capire...
Non so quale trigger viene eseguito per prima. 
Inoltre il trigger trg_after_insert_clienti,
quando viene eseguito, fa scattare il trigger trg_Clienti.
Se ci fosse un trigger sulle fatture, scattarebbe un ciclo 
ricorsivo.
Fare molta attenzione e usare i trigger solo se davvero necessario!
*/

/*Cancelliamo i trigger
DROP TRIGGER query.trg_Clienti;
DROP TRIGGER query.trg_after_insert_clienti;
*/

/*Creiamo una nuova tabella*/
SELECT *, 1 AS IsActive
INTO   CorsoSQL.query.Clienti2
FROM   CorsoSQL.query.Clienti;

/*Creiamo un INSTEAD OF trigger*/
CREATE TRIGGER trg_delete_Clienti2
ON CorsoSQL.query.Clienti2
INSTEAD OF DELETE 
AS
BEGIN
    UPDATE CorsoSQL.query.Clienti2
    SET    IsActive = 0
    WHERE  IdCliente IN (SELECT IdCliente FROM Deleted);
END;

/*Proviamo a cancellare le righe*/
DELETE 
FROM  CorsoSQL.query.Clienti2
WHERE IdCliente IN (1,2);

/*Le righe non sono state cancellate, ma si è
aggiornato il valore di IsActive */
SELECT * 
FROM CorsoSQL.query.Clienti2;

/*Cancelliamo il trigger precedente*/
/*
DROP TRIGGER query.trg_delete_Clienti2;
*/

/*Vediamo la relazione tra TRIGGER e OUTPUT.
Creiamo un nuovo trigger*/
CREATE TRIGGER trg_clienti2
ON CorsoSQL.query.Clienti2
AFTER INSERT 
AS
BEGIN
    print 'trg_after_insert_clienti';
  
    UPDATE CorsoSQL.query.Clienti2
    SET    Nome = Concat(Nome,'T')
    WHERE  IdCliente IN (SELECT IdCliente FROM Inserted);
END;

/*Una OUTPUT senza INTO fallisce se la tabella ha un trigger!*/
INSERT INTO CorsoSQL.query.Clienti2
OUTPUT inserted.*
VALUES (-1,'Nicola','Iantomasi',null,null,null);

/*Creo velocemente una tabella temporanea*/
SELECT TOP 0 *
INTO   #Clienti_t
FROM   CorsoSQL.query.Clienti2;

/*Inserisco una riga in Clienti2 dove è attivo un trigger
che aggiunge la T al nome*/
INSERT INTO CorsoSQL.query.Clienti2
OUTPUT inserted.* INTO #Clienti_t
VALUES (-1,'Nicola','Iantomasi',null,null,0);

/*L'output considera il dato prima del trigger*/
SELECT * FROM CorsoSQL.query.Clienti2 WHERE IdCliente = -1 
SELECT * FROM #Clienti_t WHERE IdCliente = -1 

/*Cancelliamo il trigger precedente*/
/*
DROP TRIGGER query.trg_clienti2;
*/

/*Creiamo un INSTEAD OF INSERT trigger che forza 
l'inserimento di una riga con valori fissi*/
CREATE TRIGGER trg_clienti2_2
ON CorsoSQL.query.Clienti2
INSTEAD OF INSERT 
AS
BEGIN
    INSERT INTO CorsoSQL.query.Clienti2
    VALUES (-15,'Raffaele','Iantomasi',null,null,0);
END;

/*Creiamo velocemente una nuova tabella temporanea*/
SELECT TOP 0 *
INTO   #Clienti_t2
FROM   CorsoSQL.query.Clienti2;

/*Inseriamo una riga*/
INSERT INTO CorsoSQL.query.Clienti2
OUTPUT inserted.* INTO #Clienti_t2
VALUES (-10,'Nicola','Iantomasi',null,null,0);

/*Anche in questo caso l'output considera il dato prima del trigger*/
SELECT * FROM CorsoSQL.query.Clienti2 WHERE IdCliente = -10;
SELECT * FROM CorsoSQL.query.Clienti2 WHERE IdCliente = -15;
SELECT * FROM #Clienti_t2 WHERE IdCliente = -10;

/*Cancelliamo la tabella
DROP TABLE CorsoSQL.query.Clienti2;
*/


/*Creiamo un altro trigger sulla tabella fatture che genera un errore
in alcuni casi specifici */
CREATE TRIGGER trg_check_fatture
ON query.Fatture
AFTER INSERT,UPDATE
AS
BEGIN
     IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.Importo <= 0
    )
    BEGIN
         THROW 50001, 'Fattura con importo < 0', 1;
    END
END;

/*Proviamo a lanciare un istruzione che viola il vincolo
(per almeno una riga) */
UPDATE CorsoSQL.query.Fatture
SET    Importo = -1
WHERE  IdFattura in (1,2);

/*N.B. Avrei potuto ottenere lo stesso risultato
con un vincolo check! Un caso d'uso dei trigger è
forzare controlli non disponibili all'interno del vincolo check.

Facciamo attenzione anche a come gestire le transazioni. 
Può essere una buona idea limitarsi a sollevare l'errore nel
trigger con THROW e gestire la transazione esternamente. */


