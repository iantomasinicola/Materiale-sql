/**********************
Paramater sniffing
***********************/

/*Creiamo una procedura*/
CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome varchar(250)
AS 
BEGIN
	SELECT * 
	FROM   qep.Clienti 
	WHERE  Nome = @ParNome;

	SELECT COUNT(*) 
	FROM   qep.Clienti; 
END

/*Chiamiamola con un particolare parametro*/
EXEC qep.Ricerca @ParNome = 'Giovanni';

/*Il piano d'esecuzione creato viene "cachato".
Posso ricavare questa informazione nella 
sys.dm_exec_procedure_stats.*/
SELECT  *
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.database_id = DB_ID('CorsoSQL')
    AND a.object_id = OBJECT_ID('qep.Ricerca');

/*Se rilanciamo la procedura con un altro valore
del parametro, il piano d'esecuzione NON verrà 
comunque ricalcolato. 
Possiamo vedere come in questo caso le stime
sulla cardinalità siano errate (infatti si 
tratta delle stesse stime fatte per la prima 
esecuzione, quando il parametro era differente).
Di conseguenza potrebbe essere 
utilizzato un piano d'esecuzione non ottimale 
per il valore del parametro corrente*/

EXEC qep.Ricerca @ParNome = 'Nicola';

/*Rilanciamo la query precedente.
Il valore di execution_count è aumentato */
SELECT  *
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.database_id = DB_ID('CorsoSQL')
    AND a.object_id = OBJECT_ID('qep.Ricerca');

/*Posso ottenere anche il piano d'esecuzione 
utilizzando la sys.dm_exec_query_plan
*/
SELECT  b.query_plan,
	a.*
FROM    sys.dm_exec_procedure_stats AS a
OUTER APPLY sys.dm_exec_query_plan(a.plan_handle) AS b
WHERE   a.database_id = DB_ID('CorsoSQL')
    AND a.object_id = OBJECT_ID('qep.Ricerca');


/*Per forzare la cancellazione di quel piano d'esecuzione
posso eseguire l'istruzione DBCC FREEPROCCACHE con in input
il valore di plan_handle*/

/*ATTENZIONE 1: lanciando il comando senza parametro saranno 
eliminati tutti i piani d'esecuzione cachati! Questo potrebbe
provocare importanti rallentamenti sul sitema*/

/*ATTENZIONE 2: eliminando il piano d'esecuzione si
elimineranno anche i dati di monitoraggio delle varie
DMV */

/*ATTENZIONE 3: anche eseguendo un alter procedure (senza
ovviamente alterare il codice) eliminerò il piano d'esecuzione*/

SELECT  a.plan_handle
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.object_id = OBJECT_ID('qep.Ricerca') 
    AND a.database_id = DB_ID('CorsoSQL');

/*Copio e incollo il plan_handle precedente*/
/*
DBCC FREEPROCCACHE(0x05000500FEEEE142F069D772C801000001000000000000000000000000000000000000000000000000000000)
*/

/*Il piano d'esecuzione non è più salvato*/
SELECT  a.plan_handle
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.object_id = OBJECT_ID('qep.Ricerca') 
    AND a.database_id = DB_ID('CorsoSQL');

/*Di conseguenza verrà ricalcolato (e salvato) alla
prossima esecuzione della stored procedure*/

EXEC qep.Ricerca @ParNome = 'Nicola';

SELECT  a.plan_handle
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.object_id = OBJECT_ID('qep.Ricerca') 
    AND a.database_id = DB_ID('CorsoSQL');

/*Ora viene usato il piano generato per Nicola*/
EXEC qep.Ricerca @ParNome = 'Giovanni';


/*OPTION RECOMPILE*/
/*Con questo hint di query posso forzare la
ricompilazione di una particolare query all'interno 
della stored procedure. Attenzione a dei BUG presenti
su SQL SERVER 2008, 2012 e 2014 per cui in casi rari
si potrebbero ottenere dei risultati errati
https://kendralittle.com/course/query-tuning-with-hints-optimizer-hotfixes/recompile-bugs-and-best-practices/
*/

CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome varchar(250)
AS 
BEGIN
	SELECT * 
	FROM   qep.Clienti 
	WHERE  Nome = @ParNome
	OPTION (RECOMPILE);

	SELECT COUNT(*) 
	FROM   qep.Clienti; 
END

/*ATTENZIONE: anche l'ALTER PROCEDURE genera 
l'eliminazione del piano d'esecuzione*/

/*Il piano d'esecuzione della prima query verrà
ricalcolato ad ogni esecuzione della procedura */
EXEC qep.Ricerca @ParNome = 'Nicola';

EXEC qep.Ricerca @ParNome = 'Giovanni';

/*Il piano d'esecuzione resta nella cache.
Infatti ho execution count pari a 2*/
SELECT  *
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.object_id = OBJECT_ID('qep.Ricerca') 
    AND a.database_id = DB_ID('CorsoSQL');

/*Ciò che viene ricalcolato è il piano d'esecuzione della query.
Possiamo ottenere questa informazione dalla SYS.dm_exec_query_stats e
modificando la WHERE inserendo il plan_handle della stored procedure*/
SELECT 
    b.text,
	substring(b.text,(a.statement_start_offset/2) + 1, 
		(case a.statement_end_offset 
		    when -1 then datalength(b.text)
		            else a.statement_end_offset
		  end - a.statement_start_offset)/2 + 1) as query_test,
	a.sql_handle,
	a.plan_handle,
    a.creation_time,
	a.last_execution_time,
	a.execution_count
FROM SYS.dm_exec_query_stats as a
CROSS APPLY SYS.dm_exec_sql_text(A.PLAN_HANDLE) as b
WHERE 
a.plan_HANDLE = 0x050006004322B136D062864FB101000001000000000000000000000000000000000000000000000000000000;

/*Questo mostra che anche per le query può essere
salvato il piano d'esecuzione. 
ATTENZIONE:
Query scritte in modo diverso (confronto CASE SENSITIVE), 
avranno un diverso piano d'esecuzione salvato.
Lanciare le quattro query seguenti una alla volta
(in tre batch differenti)
*/
SELECT * FROM fatture;
SELECT * FROM fatture;
SELECT * FROM Fatture;
SELECT * FROM Fatture /*Commento*/;

WITH CTE AS (
SELECT 
    b.text,
	substring(b.text,(a.statement_start_offset/2) + 1, 
		(case a.statement_end_offset 
		    when -1 then datalength(b.text)
		            else a.statement_end_offset
		  end - a.statement_start_offset)/2 + 1) as query_text,	
	a.sql_handle,
	a.plan_handle,
    a.creation_time,
	a.last_execution_time,
	a.execution_count,
	a.query_hash
FROM SYS.dm_exec_query_stats as a
CROSS APPLY SYS.dm_exec_sql_text(a.plan_handle) as b)
SELECT *
FROM CTE
WHERE QUERY_TEXT LIKE 'SELECT * FROM Fatture%'
ORDER BY last_execution_time;


/*OPTION OPTIMIZE FOR UNKNOWN*/
/*Il piano d'esecuzione viene calcolato
solo una volta, utilizzando le statistiche
per un valore "medio" del parametro,
non quello effettivamente passato alla stored procedure
*/
CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome varchar(250)
AS 
BEGIN
	SELECT * 
	FROM   qep.Clienti 
	WHERE  Nome = @ParNome
	OPTION (OPTIMIZE FOR UNKNOWN);

	SELECT COUNT(*) 
	FROM   qep.Clienti; 
END;

/*Dalle statistiche osserviamo che è utilizzata 
una stima intermedia */
EXEC qep.Ricerca @ParNome = 'Nicola';

/*OPTION OPTIMIZE FOR PARAMETER*/
/*Il piano d'esecuzione viene calcolato
solo una volta, utilizzando le statistiche
per il valore specificato nell'HINT,
non quello effettivamente passato alla stored procedure
*/
CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome varchar(250)
AS 
BEGIN
	SELECT * 
	FROM   qep.Clienti 
	WHERE  Nome = @ParNome
	OPTION(OPTIMIZE FOR (@ParNome = 'Nicola')); 

	SELECT COUNT(*) 
	FROM   qep.Clienti; 
END

/*Dalle statistiche osserviamo che è utilizzata 
la stima di Nicola */
EXEC qep.Ricerca @ParNome = 'Giovanni';

/*SQL DINAMICO*/
/*Sfruttiamo il fatto che query con testo 
diverso generano piani d'esecuzione diversi.
Tramite l'SQL dinamico iniettiamo un commento
nel codice in modo da generare del codice differente
per alcuni parametri*/
CREATE OR ALTER PROCEDURE qep.Ricerca 
@ParNome VARCHAR(250)
AS 
BEGIN
	DECLARE @SQLCode NVARCHAR(4000);

	SET @SQLCode = N'SELECT * 
	FROM   qep.Clienti 
	WHERE  Nome = @ParNomeD;'
	
	IF (@ParNome = 'Nicola')
		SET @SQLCode = @SQLCode + '/*nuovo qep */'

    EXEC sp_executesql
        @stmt = @SQLCode,
        @params = N'@ParNomeD VARCHAR(50)',
        @ParNomeD = @ParNome;

	SELECT COUNT(*) 
	FROM   qep.Clienti; 
END

/*Eseguiamo la procedura con Giovanni*/

EXEC qep.Ricerca @ParNome = 'Giovanni';

/*Per Nicola, avrò un codice SQL differente.
Di conseguenza anche il piano d'esecuzione per quella 
specifica query sarà potenzialmente differente*/
EXEC qep.Ricerca @ParNome = 'Nicola';

/*Osserviamo che il piano d'esecuzione della procedura
non viene resettato */
SELECT  *
FROM    sys.dm_exec_procedure_stats AS a
WHERE   a.object_id = OBJECT_ID('qep.Ricerca') 
    AND a.database_id = DB_ID('CorsoSQL');

/*Ma ciò che cambia è il piano d'esecuzione della 
query interna (poiché si generano due query differenti).
La query precedente non funziona perché il plan_handle
della query sarà associato a quello del codice dinamico,
non della procedura originale.*/
