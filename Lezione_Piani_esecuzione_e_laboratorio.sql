/********************************
INDICI E PIANI DI ESECUZIONE
*********************************/
/*Le istruzioni presenti in questa pagina creano uno schema di nome QEP 
all'interno del database CorsoSQL, da creare in precedenza con un apposito script. 
Eseguilo solo nel tuo ambiente personale di test.
*/

CREATE SCHEMA qep;

/*********************************
Lettura e ricerca di dati
**********************************/

/*Creiamo una tabella e popoliamola con qualche riga*/
CREATE TABLE CorsoSQL.qep.Clienti (NumeroCliente INT   NOT NULL, 
					      Nome varchar(50)    NOT NULL, 
					      Cognome varchar(50) NOT NULL);

INSERT INTO CorsoSQL.qep.Clienti (NumeroCliente,Nome,Cognome)
VALUES ( 1,'Nicola','Iantomasi'),
	   (2,'Giovanni','Rossi'), 
	   (3,'Giovanni','Verdi');

/*Analizziamo i piani di esecuzione di queste tre query
Per attivare la visualizzazione del piano di esecuzione effettivo
cliccare su "Includi piano di esecuzione effettivo" 
(oppure CTRL + M)*/

SELECT NumeroCliente,Nome,Cognome 
FROM   qep.Clienti;

SELECT NumeroCliente,Nome,Cognome 
FROM   qep.Clienti 
WHERE  Nome = 'Nicola';

SELECT NumeroCliente,Nome,Cognome  
FROM   qep.Clienti 
WHERE  NumeroCliente = 1;

/*Tutte e tre le volte è stato eseguito un algoritmo
di scansione*/


/*Aggiungiamo una chiave primaria*/
ALTER TABLE    CorsoSQL.qep.Clienti 
ADD CONSTRAINT ChiavePrimaria 
PRIMARY KEY /*CLUSTERED*/ (NumeroCliente);

/*Analizziamo come sono cambiati i piani di esecuzione 
delle tre query precedenti*/
SELECT NumeroCliente,Nome,Cognome 
FROM   qep.Clienti;

SELECT NumeroCliente,Nome,Cognome 
FROM   qep.Clienti 
WHERE  Nome = 'Nicola';

SELECT NumeroCliente,Nome,Cognome  
FROM   qep.Clienti 
WHERE  NumeroCliente = 1;

/*Nei primi due casi ho un algoritmo di scansione,
nel terzo caso ho un algoritmo di ricerca ottimizzata (seek)*/

/*********************************
CREAZIONE INDICI NON CLUSTERED
*********************************/
/*Aggiungiamo un indice NON CLUSTERED sulla colonna nome */
CREATE INDEX IX_clienti_nome ON CorsoSQL.qep.Clienti(Nome);

/*Rilanciamo le tre query precedenti */
SELECT NumeroCliente, Nome, Cognome 
FROM   qep.Clienti;

SELECT NumeroCliente, Nome, Cognome 
FROM   qep.Clienti 
WHERE  Nome = 'Nicola';

SELECT NumeroCliente,Nome,Cognome  
FROM   qep.Clienti 
WHERE  NumeroCliente = 1;

/*Nella seconda query ho di nuovo un algoritmo di scansione.
L'utilizzo dell'indice non clustered appena creato non erano
scontato in quanto la query coinvolge anche la colonna
cognome non presente nell'indice.
Proviamo a modificare la clausola select*/

SELECT NumeroCliente, Nome FROM qep.Clienti ;
SELECT NumeroCliente, Nome FROM qep.Clienti WHERE Nome = 'Nicola';
SELECT NumeroCliente, Nome FROM qep.Clienti WHERE NumeroCliente = 1;

/*In questo caso anche per la seconda query 
avrò un algoritmo di ricerca ottimizzato (seek)*/

/*Aggiungiamo nuove righe tutte con lo stesso valore nella
colonna nome */
INSERT INTO CorsoSQL.qep.Clienti (NumeroCliente, Nome, Cognome)
SELECT TOP 10000 3 + ROW_NUMBER() OVER(ORDER BY (SELECT NULL)),'Nicola','Rossi' 
FROM   sys.objects a CROSS JOIN sys.objects b;

/*Analizziamo nuovamente i QEP di queste due query*/
SELECT NumeroCliente, Nome, Cognome  
FROM   qep.Clienti 
WHERE  Nome = 'Nicola';

SELECT NumeroCliente, Nome, Cognome  
FROM   qep.Clienti 
WHERE  Nome = 'Giovanni'; 

/*Nel primo caso è effettuata una scansione, nel secondo
caso una ricerca ottimizzata nell'indice (più un loop di
ricerche della chiave primaria per estrarre anche la colonna
cognome */

/*Visualizziamo le statistiche associate all'indice*/
DBCC SHOW_STATISTICS ('qep.Clienti', 'IX_clienti_nome');

/*Facciamo molta attenzione a questo esempio.
Applicare una funzione ad una colonna impedisce
l'utilizzo di un algoritmo di ricerca ottimizzato
su quella colonna*/ 
SELECT NumeroCliente, Nome, Cognome  
FROM   qep.Clienti 
WHERE  CONCAT(Nome,'') = 'Giovanni'; 

/*Osserviamo come l'algoritmo di ricerca ottimizzato (seek)
sia stato sostituito da una scansione (scan)*/

/*********************************
IMPATTO DEL CODICE PARAMETRICO
*********************************/

/*Vediamo che invece la situazione cambia 
se utilizzo delle variabili */
DECLARE @Nome VARCHAR(50);
SET @Nome = 'Nicola' ;

SELECT * 
FROM   qep.Clienti 
WHERE  Nome = @Nome;

SET @Nome = 'Giovanni' ;

SELECT * 
FROM   qep.Clienti 
WHERE  Nome = @Nome;

/*Con le procedure il comportamento è ancora differente.
Anticipiamo il problema del parameter sniffing*/
CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome varchar(250)
AS 
SELECT * 
FROM   qep.Clienti 
WHERE  Nome = @ParNome;

EXEC qep.Ricerca @ParNome = 'Nicola';
EXEC qep.Ricerca @ParNome = 'Giovanni';

/*Diverso invece è il comportamento delle 
viste parametriche (inline table value function) */
CREATE FUNCTION qep.VistaRicerca (@ParNome as varchar(50))
RETURNS TABLE 
AS RETURN
SELECT * 
FROM   qep.Clienti 
WHERE  Nome = @ParNome;
	
SELECT * FROM qep.VistaRicerca('Nicola');
SELECT * FROM qep.VistaRicerca('Giovanni'); 	

/*ovviamente tutto viene perso se uso le variabili all'esterno*/
DECLARE @nome varchar(50); 
SET @nome = 'Giovanni';

SELECT * FROM qep.VistaRicerca(@nome);

/************************************
ORDINAMENTO E RIMOZIONE DUPLICATI
*é***********************************/
/*Aggiungiamo una distinct e un order by
sulla colonna chiave primaria */
SELECT NumeroCliente FROM qep.Clienti;
SELECT DISTINCT NumeroCliente FROM qep.Clienti;
SELECT NumeroCliente FROM qep.Clienti ORDER BY NumeroCliente;
SELECT DISTINCT NumeroCliente FROM qep.Clienti ORDER BY NumeroCliente;

/*La distinct è completamente trascurata. L'order by NON
porta ad eseguire un algoritmo di ordinamento, implica
solo di effettuare una scansione ordinata all'interno 
dell'indice clustered (già ordinato per NumeroCliente)*/


/*Aggiungiamo una distinct e un order by
su una colonna con indice non clustered */
SELECT Nome FROM qep.Clienti;
SELECT DISTINCT Nome FROM qep.Clienti;
SELECT Nome FROM qep.Clienti ORDER BY Nome;
SELECT DISTINCT Nome FROM qep.Clienti ORDER BY Nome;

/*La distinct è tradotta con un efficiente algoritmo di 
stream aggregate. L'order by NON porta ad eseguire un 
algoritmo di ordinamento, implica
solo di effettuare una scansione ordinata all'interno 
dell'indice non clustered (già ordinato per Nome)*/


/*Aggiungiamo una distinct e un order by
su una colonna senza indice*/
SELECT Cognome FROM qep.Clienti;
SELECT DISTINCT Cognome FROM qep.Clienti;
SELECT Cognome FROM qep.Clienti ORDER BY Cognome;
SELECT DISTINCT Cognome FROM qep.Clienti ORDER BY Cognome;

/*La distinct è tradotta con un algoritmo più pesante di 
hash aggregate. L'order by porta ad eseguire un 
pesante algoritmo di ordinamento. */


/*Con la group by il comportamento è analogo alla DISTINCT.
Attenzione però a cosa inseriamo nella select perché
potremmo perdere i vantaggi dati dalla presenza di un indice*/
SELECT NumeroCliente FROM qep.Clienti GROUP BY NumeroCliente;
SELECT Nome FROM qep.Clienti GROUP BY Nome;
SELECT Cognome FROM qep.Clienti GROUP BY Cognome;

SELECT Nome, COUNT(*) FROM qep.Clienti GROUP BY Nome;
SELECT Nome, SUM(LEN(Cognome)) FROM qep.Clienti GROUP BY Nome;

/*Perché questa query esegue comunque uno stream aggregate?*/
SELECT Nome, 
	COUNT(Cognome) 
FROM qep.Clienti 
GROUP BY Nome;


/*********************
ALGORITMI DI JOIN
*********************/
/*Analizziamo gli algoritmi di JOIN*/

/*Ogni volta SQL Server scegle in base alle 
statistiche l'algoritmo fisico di JOIN 
e l'ordinamento con cui effettuare la JOIN*/

/*Se non ho entrambe le tabelle ordinate 
secondo il criterio di JOIN e le cardinalità sono simili,
tendenzialmente userà una HASH JOIN*/
SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	on F.IdCliente = C.IdCliente;


/*Diminuendo il numero di righe di una o entrambe le tabelle
potrebbe essere eseguita una nested join*/
SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente
WHERE F.IdFattura < 100;


SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente
WHERE F.IdFattura < 1000;



SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente
WHERE F.IdFattura < 5000;


/*Risulta interessante notare come l'algoritmo cambia 
modificando il valore 100. Proviamo con 5000 o 1000 */


/*Se entrambe le fonti dati sono ordinate
secondo il criterio di JOIN tendenzialmente
verrà scelta una MERGE JOIN */
SELECT *
FROM   dbo.Fatture as F
LEFT JOIN dbo.FattureProdotti as C
	ON F.IdFattura = C.IdFattura
WHERE F.IdFattura < 100;


/*Proviamo a creare un indice sulla colonna IdCliente
della Tabella delle fatture*/
CREATE INDEX IX_IdCliente ON CorsoSQL.dbo.Fatture(IdCliente);

/*Il piano d'esecuzione di questa query non cambia.
Questo perché sono richieste tutte le colonne della
tabella Fatture*/
SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente;


/*Ma modificando la select...*/
SELECT F.IdFattura, C.*
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	on F.IdCliente = C.IdCliente;


/*Oppure in presenza di un filtro molto selettivo*/
SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente
WHERE C.IdCliente = 10029;

SELECT *
FROM   dbo.Fatture as F
INNER JOIN dbo.Clienti as C
	ON F.IdCliente = C.IdCliente
WHERE C.IdCliente = 1;

/*Nel primo caso è utilizzata la seek nell'indice non clustered
(più il recupero delle altre colonne tramite i valori di IdFattura
associati), nel secondo caso una scansione. */


/*Caso molto particolare!
Ogni regola ha un'eccezione*/
ALTER TABLE CorsoSQL.qep.clienti 
ADD CHECK (nome in ('Alberto','Giovanni','Nicola'));

/*Guarda com'è valorizzata 
la proprietà Optimization Level */
SELECT Nome, NumeroCliente 
FROM   qep.Clienti 
WHERE  Nome = 'francesco';

SELECT * 
FROM   qep.Clienti 
WHERE  Nome = 'francesco';


/*********************************
ORDINE DELLE COLONNE ALL'INTERNO
DI UN INDICE (SIA CLUSTERED E
SIA NON CLUSTERED)
*********************************/

/*Vediamo un altro esercizio.
Confrontiamo queste due query sulla tabella FattureProdotti
1) Calcola il prezzo unitario medio per ogni prodotto
2) Calcola il prezzo unitario medio per ogni fattura
*/
SELECT   IdFattura, 
		 AVG(PrezzoUnitario)  AS MediaPrezzo
FROM     dbo.FattureProdotti
GROUP BY IdFattura;

SELECT   IdProdotto, 
		 AVG(PrezzoUnitario)  AS MediaPrezzo
FROM     dbo.FattureProdotti
GROUP BY IdProdotto;

/*Vediamo cosa succede con le Join*/
SELECT   * 
FROM     dbo.FattureProdotti AS Fp
INNER JOIN dbo.Fatture AS F
	ON Fp.IdFattura = F.IdFattura;
	
SELECT   * 
FROM     dbo.FattureProdotti AS Fp
INNER JOIN dbo.Prodotti AS P
	ON Fp.IdProdotto = P.IdProdotto;


/*L'indice clustered su FattureProdotti è (IdFattura, IdProdotto) 
di conseguenza l'ordinamento è principalmente su IdFattura.
Ha senso allora aggiungere un indice come questo*/
CREATE INDEX Ix_IdProdotto 
ON CorsoSQL.dbo.FattureProdotti(IdProdotto)
INCLUDE (PrezzoUnitario);

/*Ha poco senso creare il prossimo indice.
Verrebbe usato solo perché ha dimensioni più piccole */
CREATE INDEX Ix_IdFattura 
ON CorsoSQL.dbo.FattureProdotti(IdFattura);


/*ATTENZIONE: Chiave primaria e indice clustered possono
essere disaccoppiati*/

ALTER TABLE CorsoSQL.dbo.FattureProdotti
DROP CONSTRAINT [PkFattureProdotti]

CREATE CLUSTERED INDEX IX_Clustered_IdProdotto
ON CorsoSQL.dbo.FattureProdotti(IdProdotto)

ALTER TABLE CorsoSQL.dbo.FattureProdotti
ADD PRIMARY KEY (IdFattura, IdProdotto);

/*In questo caso non ha nessun senso disaccoppiare
i due concetti, come nella grande maggior parte dei casi. 
Potrebbe aver più senso scegliere un'ipotetica colonna 
DATETIME DataInserimentoOrdine se la maggior parte delle 
query eseguono filtri su questa colonna */



/***************************
GROUP BY SU PIÙ COLONNE
***************************/

/*Iniziamo cancellando tutti gli indici presenti 
ad eccezione di quello clustered.
Creiamo questi due indici*/

CREATE INDEX IX_DataFattura 
ON CorsoSQL.dbo.Fatture(DataFattura);

CREATE INDEX IX_IdCliente 
ON CorsoSQL.dbo.Fatture(IdCliente);

/*Lanciamo queste quattro query*/
SELECT    DataFattura,IdCliente, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  DataFattura,IdCliente;

SELECT    IdCliente, DataFattura, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  IdCliente, DataFattura;

SELECT    DataFattura, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  DataFattura;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  IdCliente;

/*Quale di queste quattro query è ottimizzata? */

/*L'algoritmo di stream aggregate è presente solo 
per le ultime due.*/

/*Se voglio ottimizzare tutte e quattro le query
con due soli indici, quali devo creare? */

/*Cancelliamo gli indici precedenti*/
DROP INDEX IX_DataFattura ON CorsoSQL.dbo.Fatture;
DROP INDEX IX_IdCliente ON CorsoSQL.dbo.Fatture;

/*Ricreiamo quello sul IdCliente e creiamo uno
doppio su DataFattura, IdCliente */
CREATE INDEX IX_IdCliente 
ON CorsoSQL.dbo.Fatture(IdCliente);

CREATE INDEX IX_DataFattura_IdCliente 
ON CorsoSQL.dbo.Fatture(DataFattura, IdCliente);

/*Rilanciamo le quattro query */
SELECT    DataFattura,IdCliente, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  DataFattura,IdCliente;

SELECT    IdCliente, DataFattura, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  IdCliente, DataFattura;

SELECT    DataFattura, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  DataFattura;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
GROUP BY  IdCliente;

/*Tutte e quattro le query utilizzano lo stream aggregate!*/

/*Analizziamo queste altre tre query*/

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura = '20220812'
GROUP BY  IdCliente;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura > '20220812'
GROUP BY  IdCliente;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura IN ( '20220812','20220813')
GROUP BY  IdCliente;

/*
In ogni caso è eseguita una ricerca ottimizzata.
Ma l'algoritmo di stream aggregate è eseguito solo
per la prima query. Nella terza è anticipato da una sort,
"quindi non vale"*/

/*Aggiungiamo un altro indice doppio a colonne invertite*/
DROP INDEX IX_IdCliente ON CorsoSQL.dbo.Fatture;

CREATE INDEX IX_IdCliente_DataFattura
ON CorsoSQL.dbo.Fatture(IdCliente, DataFattura);

/*Rilanciamo le tre query */
SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura = '20220812'
GROUP BY  IdCliente;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura > '20220812'
GROUP BY  IdCliente;

SELECT    IdCliente, COUNT(*)
FROM      dbo.Fatture 
WHERE     DataFattura IN ( '20220812','20220813')
GROUP BY  IdCliente;

/*Cosa succede ai piani d'esecuzione?*/

/*Sulla prima query non ci sono dubbi.
Sulla seconda è data priorità allo stream aggregate,
sulla terza alla ricerca ottimizzata.*/

/*L'operazione di filtro è più resiliente
all'aggiunta di altre colonne*/
SELECT    IdCliente, SUM(Spedizione)
FROM      dbo.Fatture 
WHERE     DataFattura = '20220812'
GROUP BY  IdCliente;

/*Ma dipende sempre dalla stima 
sul valore nella WHERE. In questo
caso torna una semplice scansione*/
SELECT    IdCliente, SUM(Spedizione)
FROM      dbo.Fatture 
WHERE     DataFattura = '20220813'
GROUP BY  IdCliente;

/*Conviene includere nell'indice la "misura" più 
spesso utilizzata nelle query*/
CREATE INDEX IX_DataFattura_IdCliente_Spedizione
ON CorsoSQL.dbo.Fatture(DataFattura, IdCliente)
INCLUDE (Spedizione);

DROP INDEX IX_DataFattura_IdCliente 
ON CorsoSQL.dbo.Fatture;

/*Avrò per questa query di nuovo l'algoritmo
di seek + stream aggregate a prescindere dal valore*/
SELECT    IdCliente, SUM(Spedizione)
FROM      dbo.Fatture 
WHERE     DataFattura = '20220813'
GROUP BY  IdCliente;

/*ATTENZIONE:
Quando creiamo degli indici, l'unico controllo che SQL Server 
fa è sulla coppia "nome indice" - "nome tabella", 
non sulle colonne degli indici */

CREATE INDEX TEST ON CorsoSQL.dbo.Fattura(IdFattura);
CREATE INDEX TEST2 ON CorsoSQL.dbo.Fattura(IdFattura);

DROP INDEX TEST ON CorsoSQL.dbo.Fattura;
DROP INDEX TEST2 ON CorsoSQL.dbo.Fattura;




/*********************************
Warning dei piani d'esecuzione
*********************************/
/*SQL Server ha chiesto eccessiva memoria RAM in relazione 
a quella effettivamente utilizzata*/
SELECT f2.IdCliente, c.Regione, f2.DataFattura
FROM   dbo.Clienti as c
CROSS APPLY (SELECT TOP 1
                 f.IdCliente, f.DataFattura
             FROM  dbo.Fatture as f
			 WHERE F.IdCliente = C.IdCliente
			 ORDER BY DataFattura
    ) AS f2;
	
/*Facciamo attenzione all'operatore Eagager Spool. 
Molto spesso potremmo prendere in considerazione
l'idea di creare l'indice oggetto dell'operatore*/


/*SQL Server ha chiesto un quantitativo di memoria RAM 
non sufficiente per l'esecuzione della query. Ha dovuto
usare memoria fisica sul TempDB */
CREATE OR ALTER PROCEDURE dbo.test_spill 
@nome VARCHAR(255)
AS
BEGIN
	SELECT * 
	FROM   qep.clienti 
	WHERE  nome=@nome
	ORDER BY cognome;
END

EXEC CorsoSQL.dbo.test_spill 'Alberto';

/*Si genera il warning*/
EXEC CorsoSQL.dbo.test_spill 'Nicola';


/*Una conversione di formato impatta la stima delle statistiche*/
SELECT *
FROM   dbo.fatture
WHERE  CONVERT(VARCHAR(50),DataFattura,112) = '20240101';

/*Osserviamo che la stima precedente non è corretta come 
interrogando direttamente la colonna */
SELECT *
FROM   dbo.fatture
WHERE  DataFattura = '20240101';

/*Attenzione ai falsi positivi. In questo caso
il warning non è motivo di preoccupazione */
SELECT CONVERT(VARCHAR(50),DataFattura,101) AS Data
FROM   dbo.fatture
WHERE  DataFattura = '20240101';


/*Join senza predicato.
In questo caso il warning è segnalato
anche dal piano d'esecuzione stimato.
Per i nostri fini di test
la top 10 è fondamentale altrimenti
le query sarebbero lentissime*/
SELECT TOP 10 *
FROM   Fatture AS F,
   Clienti AS C;
   
SELECT TOP 10 *
FROM   Fatture AS F
INNER JOIN Clienti AS C
	ON F.IdCliente = F.IdCliente;
   
   
/**********************************
PIANI D'ESECUZIONE IN PARALLELO
**********************************/
/*Alla prima esecuzione otteniamo un hint se è attiva la
feature dei piani d'esecuzione in parallelo.
Osserviamo i valori delle proprietà in memory grant Info*/
SELECT *
FROM   dbo.Fatture as f
ORDER BY DataPagamento


/*Tuttavia eseguendo nuovamente la query vediamo come
la memoria richiesta sia stata adattata*/
SELECT *
FROM   dbo.Fatture as f
ORDER BY DataPagamento


/*Comunque non è detto che le performance
siano sempre migliori con il parallelismo.
Generalmente ci aspettiamo di sì*/
SET STATISTICS TIME ON

SELECT *
FROM   dbo.Fatture as f
ORDER BY DataPagamento

SELECT *
FROM   dbo.Fatture as f
ORDER BY DataPagamento
OPTION (maxdop 1)

SET STATISTICS TIME OFF


/*Vediamo come l'utilizzo di una funzione
può impedire il parallelismo*/
CREATE or alter FUNCTION dbo.Test(@input int)
RETURNS DECIMAL(18,2)
AS
BEGIN
DECLARE @Valore DECIMAL(18,2)

IF @input > 0
	set @Valore = (SELECT MAX(@input) FROM Fatture WHERE IDFATTURA = @INPUT) * 2

RETURN @Valore
END

/*Eseguiamo questa query*/
SELECT *, DBO.Test(IdFattura)
FROM   dbo.Fatture as f
ORDER BY DataPagamento

/*Solo nelle ultime versioni SQL Server riesce a parallelizzare
alcune funzioni, ad esempio se in precedenza togliamo 
il MAX, la funzione viene parallelizzata. */



/******************************
LABORATORIO
*******************************/
/*Esercizio 1: 
dopo aver creato l'indice, ottimizza la query seguente */
CREATE INDEX IX_DataFattura  ON CorsoSQL.dbo.Fatture(DataFattura);

SELECT COUNT(*)
FROM   dbo.Fatture
WHERE  YEAR(DataFattura) = 2023;

/*SOLUZIONE: scriviamo la query con un filtro SARGABLE,
passeremo da un Index scan ad un Index seek */
SELECT *
FROM   dbo.Fatture
WHERE  DataFattura >= '20230101'
   AND DataFattura < '20240101';


/*Esercizio 1bis: 
ottimizza la query seguente */
SELECT COUNT(*)
FROM   dbo.Fatture
WHERE  YEAR(DataFattura) = YEAR(Getdate()) - 1;

/*SOLUZIONE: scriviamo la query con un filtro SARGABLE,
passeremo da un Index scan ad un Index seek */
SELECT COUNT(*)
FROM   dbo.Fatture
WHERE  DataFattura >= DATEFROMPARTS(YEAR(Getdate())-1,1,1)
   AND DataFattura < DATEFROMPARTS(YEAR(Getdate()),1,1);


/*Esercizio 2:
dopo aver creato l'indice, ottimizza la query seguente */
CREATE INDEX Ix_nome ON CorsoSQL.dbo.Clienti(Nome)

SELECT COUNT(*) 
FROM   dbo.Clienti
WHERE  LEFT(Nome,1) = 'N'

/*SOLUZIONE: scriviamo la query con un filtro SARGABLE,
passeremo da un Index scan ad un Index seek */
SELECT COUNT(*) 
FROM   dbo.Clienti
WHERE  Nome LIKE 'N%'


/*Esercizio 3: 
dopo aver creato l'indice, ottimizza la query seguente */
CREATE INDEX ix_data_ora ON CorsoSQL.dbo.DataOra(mydate, mytime);

SELECT COUNT(*)
FROM  dbo.DataOra
WHERE CAST(mydate as datetime) + 
	  CAST(mytime as datetime)
	     >= CAST('19800301 15:00:00' AS Datetime)
AND CAST(mydate as datetime) + 
    CAST(mytime as datetime)
	     < CAST('19800401 15:00:00' AS Datetime) 

/*Soluzione 1:
Scriviamo la query con un filtro SARGABLE,
In questo caso però avremmo bisogno di una OR che in alcuni 
casi potrebbe portare a deterioramenti delle performance.*/

SELECT COUNT(*)
FROM  dbo.DataOra
WHERE mydate BETWEEN '19800302' AND '19800331'
OR  (mydate = '19800301' and MyTime >= '15:00:00')
OR  (mydate = '19800401' and MyTime < '15:00:00');

/*Soluzione 2:
aggiungiamo alla query un "sovra filtro" sargable sulla sola 
colonna mydate che sarà utilizzato
per effettuare una prima efficiente scrematura dei dati.
Osservazione: la posizione del nuovo filtro (prima o dopo quelli 
già esistenti) non ha effetto*/
SELECT COUNT(*)
FROM  dbo.DataOra
WHERE 
MyDate BETWEEN '19800228' AND '19800402'
AND
CAST(mydate as datetime) + 
	  CAST(mytime as datetime)
	     >= CAST('19800301 15:00:00' AS Datetime)
AND CAST(mydate as datetime) + 
    CAST(mytime as datetime)
	     < CAST('19800401 15:00:00' AS Datetime) 


/*Esercizio 4:
dopo aver creato l'indice, ottimizza la query seguente */
CREATE INDEX Ix_regione ON CorsoSQL.dbo.Clienti(Regione)
SELECT   COUNT(*) 
FROM     dbo.Clienti
WHERE    COALESCE(Regione,'')='';

/*SOLUZIONE 1: scriviamo la query con un filtro SARGABLE,
In questo caso però avremmo bisogno di una OR che in alcuni 
casi potrebbe portare a deterioramenti delle performance.
Osserviamo infatti che il piano d'esecuzione è più 
complicato del previsto */
SELECT   COUNT(*) 
FROM     dbo.Clienti
WHERE    Regione = '' OR Regione IS NULL;

/*SOLUZIONE 2: sostituiamo la or forzando direttamente la doppia ricerca*/
SELECT (SELECT   COUNT(*)  
		FROM     dbo.Clienti
		WHERE    Regione = '') 
	+ (SELECT   COUNT(*)  
		FROM     dbo.Clienti
		WHERE    Regione IS NULL);


/*Esercizio 5: 
ottimizza la query seguente*/
SELECT *
FROM Fatture 
WHERE DataFattura = '2020-08-12'
 OR DataFattura = (SELECT MAX(DataArrivoEffettiva) as Data 
				   FROM Fatture)
					

/*Soluzione: la query impiega tantissimo tempo, 
dal piano d'esecuzione stimato notiamo una loop join 
sulle 90000 righe della tabella Fatture. Proviamo a riscrivere la
condizione nella IN in modo più naturale. Nel nuovo piano d'esecuzione
andremo semplicmente a cercare le due date all'interno
della tabella Fatture.
*/
SELECT *
	FROM  dbo.Fatture 
	WHERE DataFattura IN 
			(SELECT MAX(DataArrivoEffettiva) as Data 
				FROM Fatture
				UNION ALL
			 SELECT '2020-08-12'
			);


/*Esercizio 6: 
ottimizza la query seguente */
SELECT 
	IdCliente AS Id,
	CONCAT(Nome,' ',Cognome) AS Denominazione,
	Telefono,
	'Cliente' AS Tipologia
FROM   dbo.Clienti
	UNION 
SELECT 
	IdFornitore AS Id,
	Denominazione,
	Telefono,
	'Fornitore' as Tipologia
FROM   dbo.Fornitori
	UNION
SELECT 
	IdCorriere AS Id,
	Denominazione,
	Telefono,
	'Corriere' as Tipologia
FROM   dbo.Corrieri;

/*Soluzione: in questo caso posso sostituire union
con union all per evitare il check sulla rimozione
dei duplicati. Nel QEP, passeremo da due "merge join (union)" ad 
una "concatenation" */

SELECT 
	IdCliente AS Id,
	CONCAT(Nome,' ',Cognome) AS Denominazione,
	Telefono,
	'Cliente' AS Tipologia
FROM   dbo.Clienti
	UNION ALL
SELECT 
	IdFornitore AS Id,
	Denominazione,
	Telefono,
	'Fornitore' as Tipologia
FROM   dbo.Fornitori
	UNION ALL
SELECT 
	IdCorriere AS Id,
	Denominazione,
	Telefono,
	'Corriere' as Tipologia
FROM   dbo.Corrieri;


/*Esercizio 7: 
dopo aver creato l'indice, ottimizza la query */
CREATE INDEX IxDataFattura ON CorsoSQL.dbo.Fatture(DataFattura)

SELECT YEAR(DataFattura) AS Anno, 
	COUNT(*) AS Numero
FROM   dbo.Fatture
GROUP BY YEAR(DataFattura);

/*Forziamo l'utilizzo dell'indice aggregando prima 
su DataFattura. A questo punto avremo poche righe su cui effettuare
una seconda aggregazione meno efficiente*/
WITH PrimoRaggruppamento AS (
	SELECT DataFattura, 
		COUNT(*) AS Numero
	FROM   dbo.Fatture
	GROUP BY DataFattura)
SELECT YEAR(DataFattura) AS Anno,
    SUM(Numero) AS Numero
FROM  PrimoRaggruppamento
GROUP BY YEAR(DataFattura);


/*Esercizio 7: 
creata la vista ReportFattureMensile e ottimizza la query successiva */
CREATE VIEW dbo.ReportFattureMensile AS
SELECT   DataFattura,
	     IdFornitore,
	     SUM(Spedizione) as Spedizione
FROM     dbo.Fatture
GROUP BY DataFattura,
	     IdFornitore;

SELECT   DataFattura,
	SUM(Spedizione) as Spedizione
FROM     dbo.ReportFattureMensile
GROUP BY DataFattura


/*Soluzione.
Osserviamo preliminarmente che la query precedente è equivalente a*/
SELECT   DataFattura,
	SUM(Spedizione) as Spedizione
FROM     (SELECT   DataFattura,
				   IdFornitore,
				SUM(Spedizione) as Spedizione
		  FROM     dbo.Fatture
		  GROUP BY DataFattura,
				   IdFornitore ) as ReportFattureMensile
GROUP BY DataFattura

/*eseguire la query a partire dalla vista, ci 
costringe ad eseguire un raggruppamento in più (che non sfrutta a dovere l'indice). 
A costo di duplicare parzialmente il codice, potremmo avere delle
performance migliori.*/

SELECT   DataFattura,
	     SUM(Spedizione) as Spedizione
FROM     dbo.Fatture
GROUP BY DataFattura;

/*La situazione sarebbe diversa se la vista fosse materializzata*/


/*Esercizio 8:  
ottimizza la query */
SELECT   Regione,
	     COUNT(*) as numero
FROM     dbo.Clienti
GROUP BY Regione
	UNION ALL
SELECT 'Totale',
	    COUNT(*) as numero
FROM    dbo.Clienti

/*Soluzione: possiamo evitare la doppia scansione con il costrutto
GROUPING SETS */
SELECT CASE WHEN GROUPING_ID(Regione)=0 
		    THEN Regione 
		    ELSE 'Totale' 
	   END as Regione,
	    COUNT(*) as numero
FROM   dbo.Clienti
GROUP BY GROUPING SETS (  (Regione),()   );


/*Esercizio 9: 
c'è differenza tra queste query a livello di performance*/
SELECT * 
FROM   dbo.Fatture as f
INNER JOIN dbo.Clienti as c
  ON f.idcliente = c.idcliente
WHERE  Nome='Nicola' 
   AND Spedizione>1

SELECT * 
FROM   dbo.Fatture as f
INNER JOIN dbo.Clienti as c
  ON f.idcliente = c.idcliente
   AND  Nome='Nicola' 
   AND Spedizione>1		 

SELECT * 
FROM   (SELECT * FROM dbo.Fatture WHERE Spedizione>1) as f
INNER JOIN (SELECT * FROM dbo.Clienti WHERE Nome='Nicola' )as c
  ON f.idcliente = c.idcliente

/*Soluzione: NO, in queste query l'ordine con cui sono 
effettuati i filtri non modifica il risultato. Di conseguenza
SQL Server sceglie in ogni caso la modalità più efficiente (filtrare 
all'inizio). */


/*Esercizio 10: 
dopo aver creato l'indice, ottimizza la query seguente */
CREATE INDEX IX_Cliente ON CorsoSQL.dbo.Fatture(IdCliente)
SELECT *
FROM   Clienti AS C
LEFT JOIN Fatture AS F
	ON C.IdCliente = F.IdCliente
WHERE F.IdCliente IS NULL;

/*Soluzione: per costruzione, tutte le colonne della tabella fatture
saranno NULL. Tuttavia SQL Server non se ne accorge e quindi 
non utilizza l'indice creato sulla colonna IdCliente. Basterà modificare
la SELECT chiedendo soltanto le colonne della Tabella Clienti.
Passeremo da una Hash Join ad una Merge Join*/

SELECT C.*
FROM   Clienti AS C
LEFT JOIN Fatture AS F
	ON C.IdCliente = F.IdCliente
WHERE F.IdCliente IS NULL;

/* se voglio aggiungere manualmente i NULL
potrei in alcuni casi dover fare attenzione al tipo*/

SELECT C.*, 
    CAST(NULL AS int) AS IdFattura,
	CAST(NULL AS int) AS IdFornitore
	--,...
FROM   Clienti AS C
LEFT JOIN Fatture AS F
	ON C.IdCliente = F.IdCliente
WHERE F.IdCliente IS NULL;


/*Esercizio 11: 
ottimizza la query sottolineando eventuali differenze
nel risultato finale */
SELECT F.IdCorriere,
	c.Denominazione,
	SUM(Fp.prezzoUnitario*Fp.quantita - COALESCE(Fp.sconto,0)) AS Fatturato
FROM dbo.Fatture AS F
LEFT JOIN dbo.FattureProdotti AS Fp
	ON f.IdFattura=Fp.IdFattura
INNER JOIN dbo.Corrieri AS c
	ON f.IdCorriere=c.IdCorriere
GROUP BY F.IdCorriere,
	c.Denominazione

/*Soluzione
La query esegue prima una inner hash join tra Corrieri e Fatture, poi
una right hash join tra la FattureProdotti e il risultato di questa join.

Se sostituissimo la LEFT con la INNER JOIN, il piano d'esecuzione potrebbe
esplorare altri ordini diversi di eseguire le tre join, magari più efficienti.

Osserviamo che in questo caso le fatture senza prodotti associati non
concorrono al fatturato finale. L'unica differenza nel risultato potrebbe 
esserci nel caso in cui un corriere abbia SOLTANTO fatture il cui l'Id non
è mai presente nella tabella FattureProdotti. Un caso abbastanza raro
che si potrebbe accettare. 

Sostituendo la INNER con la LEFT le performance 
migliorano: è effettuata prima la join tra FattureProdotti e Fatture
e poi il risultato è in join con Corrieri*/   
SELECT F.IdCorriere,
	c.Denominazione,
	SUM(Fp.prezzoUnitario*Fp.quantita - COALESCE(Fp.sconto,0)) AS Fatturato
FROM dbo.Fatture AS F
INNER JOIN dbo.FattureProdotti AS Fp
	ON f.IdFattura = Fp.IdFattura
INNER JOIN dbo.Corrieri AS c
	ON f.IdCorriere = c.IdCorriere
GROUP BY F.IdCorriere,
	c.Denominazione


	
/*Esercizio 12:  Ottimizza la query seguente*/
SELECT * 
FROM   dbo.Clienti2 AS C
WHERE  NOT EXISTS (SELECT *
                   FROM   dbo.Fatture2 AS F
				   WHERE  C.IdCliente = F.IdCliente );


/*Soluzione 1:
Guardando il piano d'esecuzione stimato, ci accorgiamo
che vengono fatte 1000 ricerche non ottimizzate
all'interno dell'intera tabella fatture2. 
Sostituiamo la NOT EXISTS con la LEFT JOIN per
passare da una loop join ad una hash join + filtro*/
SELECT C.* 
FROM   dbo.Clienti2 AS C
LEFT JOIN dbo.Fatture2 AS F
	ON C.IdCliente = F.IdCliente
WHERE F.IdCliente IS NULL;



/*Esercizio 13: 
Ottimizza la query seguente 
Attenzione: LA QUERY PROPOSTA È TROPPO LENTA, 
NON LANCIARLA*/
SELECT	  a.* 
FROM      dbo.test1 AS a 
LEFT JOIN dbo.test2 AS b
	   ON a.campo = b.campo 
WHERE     b.campo IS NULL;

/*Soluzione: in questo caso sostituiamo la LEFT JOIN con la
NOT EXISTS. La sort + merge sarà sostituita da una hash preceduta 
da una rimozione dei duplicati*/
SELECT	  a.* 
FROM      dbo.test1 AS a 
WHERE NOT EXISTS (SELECT * 
                  FROM   dbo.test2 AS b
				  WHERE  a.campo = b.campo ) 



/*Esercizio 14: 
ottimizza la query*/
SELECT * 
FROM  qep.Clienti 
WHERE Nome = (SELECT top 1 nome 
              FROM   qep.Clienti
			  ORDER BY Cognome DESC);

--Ricorda 
SELECT * FROM qep.Clienti WHERE Nome = 'Maria'

SELECT * FROM qep.Clienti WHERE Nome = 'Nicola'

DECLARE @nome varchar(50) = 'Nicola'
SELECT * FROM qep.Clienti WHERE Nome = @nome

/*Soluzione 1:
In questo caso la stima della cardinalità del valore Nome
sarà fatto sulla stima del risultato della sottoquery. Meglio
materializzare il risultato in una tabella temporanea*/

SELECT top 1 nome 
INTO #TopNome
FROM qep.Clienti
ORDER BY Cognome desc

SELECT * FROM qep.Clienti WHERE Nome = (select Nome from #TopNome)

/* Osserviamo che in questo caso
utilizzare la IN in luogo di = migliora le performance*/
SELECT * FROM qep.Clienti WHERE Nome IN (select Nome from #TopNome)

/*Soluzione 2:
usiamo l'SQL dinamico per comporre la query corretta.
Metodo 1 non ottimale, a rischio di SQL Injection*/

DECLARE @TopNome varchar(400)
DECLARE @SqlString nvarchar(4000)

SELECT TOP 1 @TopNome = Nome 
FROM qep.Clienti
ORDER BY Cognome desc

SELECT @SqlString = N'SELECT * FROM qep.Clienti WHERE Nome = '''+@TopNome+''''

EXEC (@SqlString)

/*Metodo 2 migliore per prevenire l'SQL Injection. 
Ma può soffrire di parameter sniffing*/
DECLARE @TopNome varchar(400)

SELECT TOP 1 @TopNome = Nome 
FROM   qep.Clienti
ORDER BY Cognome desc

EXECUTE sp_executesql N'SELECT * FROM qep.Clienti WHERE Nome = @nome',
                      N'@nome varchar(500)',
					  @nome = @TopNome


/*Esercizio 15: 
ottimizza la query */

WITH SpesaAnnuale AS
	(
	SELECT   YEAR(DataFattura) AS Anno,
		     SUM(spedizione) AS SpedizioneA 
	FROM     dbo.Fatture
	GROUP BY YEAR(DataFattura)
	),
SpesaMensile AS (
	SELECT   YEAR(DataFattura) as Anno,
		     MONTH(DataFattura) as Mese,
		     SUM(Spedizione) as SpedizioneM
	FROM     dbo.Fatture AS F
	GROUP BY YEAR(DataFattura),
	         MONTH(DataFattura)
	)
SELECT a.Anno,
	   m.Mese,
	   m.SpedizioneM/a.SpedizioneA as Indicenza
FROM   SpesaAnnuale  AS a
INNER JOIN SpesaMensile AS m
	on a.Anno = m.Anno;

/*Soluzione 1: evitiamo la doppia scansione della tabella
fatture materializzando preliminarmente la spesa mensile (sarà una tabella
fatta SEMPRE da poche righe). A questo punto, avendo poche righe,
posso continuare come meglio credo.*/

SELECT   YEAR(DataFattura) as Anno,
		    MONTH(DataFattura) as Mese,
		    SUM(Spedizione) as SpedizioneM
INTO     #Mensile
FROM     dbo.Fatture AS F
GROUP BY YEAR(DataFattura),
	         MONTH(DataFattura)
	
SELECT Anno,
       Mese,
	   SpedizioneM / SUM(SpedizioneM) OVER(PARTITION BY Anno)
FROM   #Mensile;


/*Esercizio 16: ottimizza la query*/
SELECT f.IdFattura,
	   f.IdCliente,
       Spedizione / 
	      SUM(Spedizione) OVER(PARTITION BY IdCliente)
					AS Incidenza
FROM   dbo.Fatture AS f;

/*Soluzione: l'utilizzo della Window function ha un effetto peggiorativo
sulle performance. Notare anche il numero di pagine lette sul tempdb
tramite SET STATISTICS IO ON */
set statistics time on
SELECT f.IdFattura,
	   f.IdCliente,
       f.Spedizione / c.SpedizioneT AS Incidenza
FROM   dbo.Fatture AS f
INNER JOIN (SELECT IdCliente, SUM(Spedizione) AS SpedizioneT
           FROM   Fatture
		   GROUP BY IdCliente) AS c
   ON f.IdCliente = c.IdCliente 
   OR (f.IdCliente IS NULL AND c.IdCliente is null);

--Oppure
SELECT f.IdFattura,
	   f.IdCliente,
       f.Spedizione / c.SpedizioneT AS Incidenza
FROM   dbo.Fatture AS f
INNER JOIN (SELECT IdCliente, SUM(Spedizione) AS SpedizioneT
           FROM   Fatture
		   GROUP BY IdCliente) AS c
   ON EXISTS (SELECT f.IdCliente INTERSECT SELECT c.IdCliente)


/*Esercizio 17:
Quale indice migliora le performance di questa query? */
SELECT * 
FROM (
	SELECT IdCorriere, 
		   IdFattura,
		   RANK() over(partition by IdCorriere 
					   order by DataFattura desc) as rn
	FROM   dbo.Fatture) as a
WHERE  rn = 1

/*Soluzione*/
CREATE INDEX ix_windowfunction 
ON CorsoSQL.dbo.Fatture(IdCorriere, DataFattura DESC)


/*Esercizio 18:
Considerando l'indice dell'esercizio precedente, ottimizza la query */
SELECT * 
FROM (
	SELECT *,
		   RANK() OVER(PARTITION BY IdCorriere 
					   ORDER BY DataFattura DESC) AS rn
	FROM   dbo.Fatture) as a
WHERE rn = 1;

/*Soluzione, l'indice precedente non viene utilizzato in quanto sono
richieste tutte le colonne. Posso forzarne l'utilizzo con una subquery 
sulle sole colonne dell'indice e una join ulteriore. */
SELECT b.* 
FROM (
	SELECT IdFattura,
		   RANK() OVER(PARTITION BY IdCorriere 
					   ORDER BY DataFattura DESC) AS rn
	FROM   dbo.Fatture) as a
INNER JOIN dbo.Fatture as b
 ON a.IdFattura = b.IdFattura
WHERE rn = 1;


/*Esercizio 19: 
ottimizza la query */
WITH cte as (
SELECT f.IdCliente, c.Regione, f.IdFattura,
		RANK() OVER(PARTITION BY f.IdCliente 
		            ORDER BY f.DataFattura DESC) AS rn
FROM   dbo.Fatture as f
INNER JOIN dbo.Clienti as c
	ON F.IdCliente = C.IdCliente
)
SELECT *
FROM CTE
WHERE rn <= 3;

/*Soluzione 1: 
poiché la window function coinvolge soltanto colonne della 
tabella Fatture, possiamo pensare di posticipare la join e anticipare 
il filtro. Osserviamo che l'ordinamento eseguito per calcolare la funzione
rank viene ri-utilizzato per eseguire una merge join invece di hash join*/

WITH cte AS (
SELECT f.IdCliente, f.IdFattura,
		RANK() OVER(PARTITION BY f.IdCliente 
		            ORDER BY f.DataFattura DESC) AS rn
FROM   dbo.Fatture as f
)
SELECT  f.IdCliente, c.Regione, f.IdFattura
FROM CTE as f
INNER JOIN dbo.Clienti as c
	ON F.IdCliente = C.IdCliente
WHERE rn <= 3;

/*In questo caso potremmo valutare anche le prestazioni di una CROSS APPLY.
Tuttavia in questo caso la query è lentissima, NON LANCIARLA*/
SELECT F2.IdCliente, c.Regione, F2.DataFattura
FROM   dbo.Clienti as c
CROSS APPLY (SELECT TOP 3 WITH TIES
                 f.IdCliente, f.DataFattura
            FROM  dbo.Fatture AS f
	        WHERE F.IdCliente = C.IdCliente
		    order by f.datafattura desc) as f2

--ripetiamo gli esperimenti con l'indice
CREATE INDEX ix_windowfunction2 ON CorsoSQL.dbo.Fatture (IdCliente,DataFattura DESC)

/*Osserviamo che nella query iniziale viene scelta una loop join
perché è l'unica tipologia di join che preserva l'ordinamento.
Anche la Cross Apply ha buone performance */


/*Esercizio 20: 
ottimizza la query*/
with t50 AS (
	SELECT Categoria,
		COUNT(*) AS NumeroProdotti
	FROM dbo.Prodotti
	WHERE Target = '>50'
	GROUP BY Categoria
	),
t1830 AS (
	SELECT Categoria,
		COUNT(*) AS NumeroProdotti
	FROM dbo.Prodotti
	WHERE Target = '18-30'
	GROUP BY Categoria
	)
SELECT coalesce(t50.categoria, t1830.categoria) AS categoria,
	coalesce(t50.NumeroProdotti,0) AS prodotti50,
	coalesce(t1830.NumeroProdotti,0) AS prodotti1830
FROM t50 
FULL JOIN t1830
	ON t50.categoria = t1830.categoria

/*Soluzione: possiamo provare ad ottenere performance migliori
evitando la doppia scansione e la full join. Eseguiamo 
un'unica GROUP BY senza filtri con una doppia CASE WHEN.
ATTENZIONE: Otterremo un risultato  leggermente diverso in presenza di NULL
nella colonna categoria.
*/
SELECT Categoria,
	   SUM(CASE WHEN  Target = '>50' THEN 1 ELSE 0 END) AS prodotti50,
	   SUM(CASE WHEN  Target = '18-30'THEN 1 ELSE 0 END) AS prodotti1830
FROM dbo.Prodotti
GROUP BY Categoria


/*Esercizio 21:rimuovi eventuali indici sull'idCliente della tabella
Fatture e ottimizza la query*/
SELECT DISTINCT 
		  c.IdCliente, 
		  CASE WHEN f.IdCliente is null 
			   THEN 0 
		       ELSE 1 
	      END
FROM      dbo.Clienti as c
LEFT JOIN dbo.Fatture as f
       ON c.IdCliente = f.IdCliente

/*Soluzione: per ottimizzare la query potremmo provare a scrivere
la query in modo da far anticipare l'aggregazione rispetto alla join.
Ciò è possibile in più modi: */
SELECT 	  c.IdCliente, 
		  CASE 
			WHEN COUNT(f.IdCliente) > 0 THEN 1
			ELSE COUNT(f.IdCliente) 
		  END 
FROM      dbo.Clienti as c
LEFT JOIN dbo.Fatture as f
       ON c.IdCliente = f.IdCliente
GROUP BY c.IdCliente

SELECT    c.IdCliente, 
		  CASE WHEN f.IdCliente is null 
			   THEN 0 
		       ELSE 1 
	      END
FROM      dbo.Clienti as c
LEFT JOIN (SELECT DISTINCT IdCliente 
           FROM dbo.Fatture) as f
       ON c.IdCliente = f.IdCliente;

SELECT  IdCliente, 
		  CASE WHEN IdClienteF is null 
			   THEN 0 
		       ELSE 1 
	      END
FROM (
	SELECT DISTINCT 
			  c.IdCliente, 
			  f.IdCliente AS IdClienteF
	FROM      dbo.Clienti as c
	LEFT JOIN dbo.Fatture as f
		   ON c.IdCliente=f.IdCliente) AS Tab;

--Per evitare la DISTINCT potrei scrivere questa query, ma SQL Server reputa
--comunque opportuno rimuovere i duplicati per fare una join più veloce
SELECT 	  c.IdCliente, 
		  1
FROM      dbo.Clienti as c
WHERE EXISTS (SELECT * 
              FROM dbo.Fatture as f
              WHERE c.IdCliente = f.IdCliente)
UNION ALL
SELECT 	  c.IdCliente, 
		  0
FROM      dbo.Clienti as c
WHERE NOT EXISTS (SELECT * 
                  FROM dbo.Fatture as f
                  WHERE c.IdCliente = f.IdCliente)
GROUP BY c.IdCliente

--Per evitare la doppia scansione, potrei scrivere questa query ma 
--è lentissima
SELECT 	  c.IdCliente, 
		  CASE WHEN EXISTS (SELECT * 
                  FROM dbo.Fatture as f
                  WHERE c.IdCliente = f.IdCliente)
			   THEN 1
			   ELSE 0
			   END
FROM      dbo.Clienti as c

/*Tuttavia, aggiungendo un indice su IdCliente, 
diventerà la più performante!*/
CREATE INDEX ix_IdCliente ON CorsoSQL.Fatture(IdCliente)


