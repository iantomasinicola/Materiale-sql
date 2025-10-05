Set  conSql = New ADODB.Connection
    Call OpenConnectionSQL(conSql)
    
    parametri = Array(Anno)
    'DBEngine.SetOption dbMaxLocksPerFile, 360
    DBEngine.SetOption dbMaxLocksPerFile, 1500
    runActionQuery "[AmmFatEE].[SP_Aggiorna_LogisticaEE] ", parametri, conSql



/***************************************
VARIABILI, VISTE PARAMETRICHE E APPLY
****************************************/

/*Step 1
Estrarre per il fornitore numero 3, la somma degli importi
delle fatture associate, divise per anno */
SELECT   YEAR(DataFattura) AS Anno,
		 SUM(Importo) AS FatturatoAnnuo
FROM     query.Fatture
WHERE    IdFornitore = 3
GROUP BY YEAR(DataFattura);


/*Step 2
Rendere il codice precedente parametrico 
sull'IdFornitore */

--dichiariamo una variabile
DECLARE @Fornitore INT;

--valorizziamo una variabile
SET @Fornitore = 1;

--rendiamo la query parametriche dipendente dalla variabile
SELECT   YEAR(DataFattura) AS Anno,
		 SUM(Importo) AS FatturatoAnnuo
FROM     query.Fatture
WHERE    IdFornitore = @Fornitore
GROUP BY YEAR(DataFattura);

/*ATTENZIONE:
la dichiarazione della variabile vale solo
all'interno dello statement SQL eseguito. */


/*Step 3
Creare una vista parametrica
"Inline table value function" ITVF*/

/*
Ricordiamo preliminarmente come crerare una vista
CREATE VIEW query.FatturatoAnnuo
AS
SELECT   YEAR(DataFattura) AS Anno,
		 SUM(Importo) AS FatturatoAnnuo
FROM     query.Fatture
GROUP BY YEAR(DataFattura);
*/

/*Creiamo la ITVF*/
CREATE FUNCTION query.FatturatoAnnuoPerFornitore (@Fornitore int)
RETURNS TABLE
RETURN
SELECT   YEAR(DataFattura) AS Anno,
		 SUM(Importo) AS FatturatoAnnuo
FROM     query.Fatture
WHERE    IdFornitore = @Fornitore
GROUP BY YEAR(DataFattura);


/*Step 4
Eseguire la vista parametriche */
SELECT *
FROM	query.FatturatoAnnuoPerFornitore(3);


/*Step 5 
Eseguire la vista parametrica 
passando in input una variabile */
DECLARE @V_Fornitore INT;
SET     @V_Fornitore = 3;

SELECT *
FROM   query.FatturatoAnnuoPerFornitore(@V_Fornitore);


/*Step 6
Estrarre il fatturato annuo per tutti i fornitori con
regione di residenza in Lombardia*/
SELECT T.IdFornitore, 
	   F.Anno,
	   F.FatturatoAnnuo
FROM  (SELECT  * 
	   FROM    query.Fornitori
	   WHERE   RegioneResidenza ='Lombardia') AS T
CROSS APPLY query.FatturatoAnnuoPerFornitore(T.IdFornitore) AS F
ORDER BY T.IdFornitore, 
	     F.Anno;



SELECT *
FROM   query.FatturatoAnnuoPerFornitore(1)
UNION ALL 
SELECT *
FROM   query.FatturatoAnnuoPerFornitore(1)
UNION ALL 
SELECT *
FROM   query.FatturatoAnnuoPerFornitore(3)
UNION ALL 
SELECT *
FROM   query.FatturatoAnnuoPerFornitore(6)

/*come cambierebbe la query se sostituiamo
cross apply con outer apply?  */
SELECT T.IdFornitore, 
	   F.Anno,
	   F.FatturatoAnnuo
FROM  (SELECT  * 
	   FROM    query.Fornitori
	   WHERE   RegioneResidenza ='Lombardia') AS T
OUTER APPLY query.FatturatoAnnuoPerFornitore(IdFornitore) AS F
ORDER BY T.IdFornitore, 
	     F.Anno;

/*l'OUTER APPLY mostra una riga anche per il fornitore 6
che è residente in Lombardia ma per il quale la vista
parametrica restituisce zero righe */
SELECT * FROM query.FatturatoAnnuoPerFornitore(6);


/*L'apply non richiede obbligatoriamente l'utilizzo di una ITVF*/
SELECT Cl.*, fa2.*
FROM   query.Clienti AS Cl
OUTER APPLY (SELECT TOP 1 IdFattura, Importo
			 FROM   query.Fatture AS Fa
			 WHERE  Fa.IdCliente = Cl.IdCliente
			 ORDER BY Importo DESC) AS fa2


 
 /*Per salvare qualsiasi tipologia di codice posso usare le
 stored procedure*/
CREATE PROCEDURE query.MostraFattureRecentiFornitore
	@IdFornitore INT  --> non servono le parentesi prima dei parametri	
AS
BEGIN 
	/*
	UPDATE CorsoSQL.query.Fatture
	SET    Importo = Importo + Importo * COALESCE(@InteressePercentuale,0)
	WHERE  IdFattura = @IdFattura;
	*/
	
	WITH 
	 CTE AS (
		SELECT *,
			RANK() OVER(PARTITION BY IdCliente
						ORDER BY DataFattura DESC, IdFattura DESC) AS RN
		FROM   query.Fatture
		WHERE  IdFornitore = @IdFornitore)
	SELECT *
	INTO   #TEMP
	FROM   CTE
	WHERE  RN = 1;
	
	SELECT *
	FROM   #TEMP;
	
	/*
	SELECT SUM(importo) as Importo
	FROM   CorsoSQL.query.Fatture
	WHERE  IdFornitore = @IdFornitore;
	*/
END;


/*Per eseguire questo codice, utilizziamo 
la sintassi exec <NomeProcedura> parametri*/
EXEC CorsoSQL.query.MostraFattureRecentiFornitore @IdFornitore=1;

 
 
/******************************
* PIVOT E UNPIVOT DEI DATI
*******************************/

/*Esempio 1: Pivot:
Riportare per ogni anno, la somma 
degli importi divisi per fornitore.
L'output deve avere un formato matriciale dove i 
fornitori sono mostrati sulle colonne.
Ad esempio 
Anno Fornitore1 Fornitore2 Fornitore3
2018     123.45     251.41      63.01
2019     100.11     152.61     187.21
*/


--Metodo CASE WHEN IN SUM
SELECT  YEAR(DataFattura) as Anno,	
		SUM(CASE WHEN IdFornitore = 1 THEN Importo ELSE 0 END) as [Fornitore1],
		SUM(CASE WHEN IdFornitore = 2 THEN Importo ELSE 0 END) as [Fornitore2],
		SUM(CASE WHEN IdFornitore = 3 THEN Importo ELSE 0 END) as [Fornitore3],
		SUM(CASE WHEN IdFornitore = 4 THEN Importo ELSE 0 END) as [Fornitore4],
		SUM(CASE WHEN IdFornitore = 5 THEN Importo ELSE 0 END) as [Fornitore5],
		SUM(CASE WHEN IdFornitore IS NULL THEN Importo ELSE 0 END) as [FornitoreAssente]
FROM	query.Fatture
GROUP BY YEAR(DataFattura);


--Metodo clausola Pivot
WITH CTE AS (
	SELECT   YEAR(DataFattura) as anno,
			 IdFornitore,	
			 SUM(Importo)	  as TotaleImporto
	FROM	 query.Fatture
	GROUP BY YEAR(DataFattura),
		     IdFornitore
	)
SELECT Anno,
	[1] AS Fornitore1,
	[2] AS Fornitore2,
	[3] AS Fornitore3,
	[4] AS Fornitore4,
	[5] AS Fornitore5
FROM CTE
PIVOT (SUM(TotaleImporto) 
	   FOR IdFornitore IN ([1],[2],[3],[4],[5]) 
	   )  AS pvt;

--Per eliminare i null
WITH CTE AS (
	SELECT   YEAR(DataFattura) as anno,
			 IdFornitore,	
			 SUM(Importo)	  as TotaleImporto
	FROM	 query.Fatture
	GROUP BY YEAR(DataFattura),
		     IdFornitore
	)
SELECT Anno,
	COALESCE([1],0) AS Fornitore1,
	COALESCE([2],0) AS Fornitore2,
	COALESCE([3],0) AS Fornitore3,
	COALESCE([4],0) AS Fornitore4,
	COALESCE([5],0) AS Fornitore5
FROM CTE
PIVOT (SUM(TotaleImporto) 
	   FOR IdFornitore IN ([1],[2],[3],[4],[5]) 
	   )  AS pvt;


--La query precedente è equivalente a 
WITH CTE AS (
	SELECT   YEAR(DataFattura) as anno,
			 IdFornitore,	
			 Importo
	FROM	 query.Fatture
	)
SELECT Anno,
	COALESCE([1],0) AS Fornitore1,
	COALESCE([2],0) AS Fornitore2,
	COALESCE([3],0) AS Fornitore3,
	COALESCE([4],0) AS Fornitore4,
	COALESCE([5],0) AS Fornitore5
FROM CTE
PIVOT (SUM(Importo) 
	   FOR IdFornitore IN ([1],[2],[3],[4],[5]) 
	   )  AS pvt;

/*ATTENZIONE, la PIVOT raggruppa i dati implicitamente per 
le colonne presenti nella prima tabella dopo la FROM non presenti
nella funzione di aggregazione o nella clausola FOR
La prossima query dà un risultato probabilmente errato */
WITH CTE AS (
	SELECT   YEAR(DataFattura) as anno,
			 IdFornitore,
			 IdCliente,
			 Importo
	FROM	 query.Fatture
	)
SELECT Anno,
    --IdCliente,
	COALESCE([1],0) AS Fornitore1,
	COALESCE([2],0) AS Fornitore2,
	COALESCE([3],0) AS Fornitore3,
	COALESCE([4],0) AS Fornitore4,
	COALESCE([5],0) AS Fornitore5
FROM CTE
PIVOT (SUM(Importo) 
	   FOR IdFornitore IN ([1],[2],[3],[4],[5]) 
	   )  AS pvt;


--Se volessi anche una colonna per le fatture senza fornitori?
WITH CTE AS (
	SELECT   YEAR(DataFattura) as anno,
			 COALESCE(IdFornitore,-1) AS IdFornitore,
			 Importo
	FROM	 query.Fatture
	)
SELECT Anno,
	COALESCE([1],0) AS Fornitore1,
	COALESCE([2],0) AS Fornitore2,
	COALESCE([3],0) AS Fornitore3,
	COALESCE([4],0) AS Fornitore4,
	COALESCE([5],0) AS Fornitore5,
	COALESCE([-1],0) AS FornitoreAssente
FROM CTE
PIVOT (SUM(Importo) 
	   FOR IdFornitore IN ([1],[2],[3],[4],[5],[-1]) 
	   )  AS pvt;






/*UNPIVOT
Esempio2: Riscriviamo la query precedente e mettiamo il risultato
in una tabella temporanea. Eseguiamo in seguito un Unpivot */
SELECT  YEAR(DataFattura) as Anno,	
		SUM(CASE WHEN IdFornitore = 1 THEN Importo ELSE 0 END) as [Fornitore1],
		SUM(CASE WHEN IdFornitore = 2 THEN Importo ELSE 0 END) as [Fornitore2],
		SUM(CASE WHEN IdFornitore = 3 THEN Importo ELSE 0 END) as [Fornitore3],
		SUM(CASE WHEN IdFornitore = 4 THEN Importo ELSE 0 END) as [Fornitore4],
		SUM(CASE WHEN IdFornitore = 5 THEN Importo ELSE 0 END) as [Fornitore5],
		SUM(CASE WHEN IdFornitore IS NULL THEN Importo ELSE 0 END) as [FornitoreAssente]
INTO    #Pivot
FROM	query.Fatture
GROUP BY YEAR(DataFattura);


SELECT *
FROM   #Pivot;

--Eseguiamo l'Unpivot
SELECT anno, 
	convert(int,NULLIF(Replace(IdFornitore,'Fornitore',''),'Assente')) as IdFornitore,
	Importo
FROM #pivot
UNPIVOT (Importo FOR IdFornitore in ([Fornitore1],[Fornitore2],[Fornitore3],
                                     [Fornitore4],[Fornitore5],[FornitoreAssente]) ) as unpvt
									 


							 
/*********************************
* GROUPING SETS
**********************************/

/*Esempio 1
Calcolare il numero di clienti per ogni regione e aggiungere
in fondo una riga con il totale */

--vecchio metodo
SELECT *
FROM (
	SELECT RegioneResidenza,
		   COUNT(*) as Numero
	FROM query.Clienti
	GROUP BY RegioneResidenza
		UNION ALL
	SELECT 'Totale',
		   COUNT(*) as Numero
	FROM query.Clienti
	) as tab
ORDER BY CASE WHEN RegioneResidenza = 'Totale' 
              THEN 2 
			  ELSE 1 
		 END,
		 RegioneResidenza;

--Nuovo metodo: parzialmente corretto
SELECT RegioneResidenza,
	   COUNT(*) as Numero
FROM query.Clienti
GROUP BY GROUPING SETS  (  (RegioneResidenza), ()   )
ORDER BY RegioneResidenza DESC;

/*ATTENZIONE: come faccio a distinguere i NULL presenti nella colonna
RegioneResidenza, dai NULL relativi alla clausola GROUPING SETS?
*/

--Risolviamo il problema dell'ambivalenza del NULL
SELECT RegioneResidenza,
	   GROUPING_ID(RegioneResidenza) AS GROUPING_ID_RegioneResidenza,
	   COUNT(*) as Numero
FROM query.Clienti
GROUP BY GROUPING SETS  (  (RegioneResidenza), ()   )
ORDER BY RegioneResidenza DESC;


WITH step1 as (
SELECT 
	CASE WHEN GROUPING_ID(RegioneResidenza)=0 
		 THEN RegioneResidenza 
		 ELSE 'Totale' 
	END as RegioneResidenza,
	COUNT(*) as Numero
FROM query.Clienti
GROUP BY GROUPING SETS  (  (RegioneResidenza), ()   ) 
)
SELECT * 
FROM step1
ORDER BY CASE WHEN RegioneResidenza = 'Totale' 
              THEN 2 
			  ELSE 1 
		 END,
		 RegioneResidenza;


----------------------------------------------------
--Vediamo cosa succede utilizzando il raggruppamento
--predefinito rollup
SELECT GROUPING_ID(YEAR(DataNascita)) AS Grouping_ID_Anno,
	   GROUPING_ID(MONTH(DataNascita) ) AS Grouping_ID_Mese,
	   GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) ) AS Grouping_ID_Anno_Mese,
       YEAR(DataNascita) AS Anno,
	   MONTH(DataNascita) AS Mese,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY ROLLUP ( YEAR(DataNascita),MONTH(DataNascita)  ) 
ORDER BY GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) );

/*la query con ROLLUP è equivalente a */
SELECT GROUPING_ID(YEAR(DataNascita)) AS Grouping_ID_Anno,
	   GROUPING_ID(MONTH(DataNascita) ) AS Grouping_ID_Mese,
	   GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) ) AS Grouping_ID_Anno_Mese,
       YEAR(DataNascita) AS Anno,
	   MONTH(DataNascita) AS Mese,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY GROUPING SETS ( (YEAR(DataNascita),MONTH(DataNascita) ), 
						 (YEAR(DataNascita)),
						 ()
						) 
ORDER BY GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) );

--Tramite grouping_id posso disambiguare i NULL
SELECT CASE WHEN GROUPING_ID(YEAR(DataNascita)) = 0 
		    THEN CONVERT(VARCHAR(10),YEAR(DataNascita))
            ELSE 'Tutti' 
	   END AS Anno,
	   CASE WHEN GROUPING_ID(MONTH(DataNascita) ) = 0 
	        THEN MONTH(DataNascita)  
			ELSE 'Tutti' 
	   END AS Mese,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY GROUPING SETS ( (YEAR(DataNascita),MONTH(DataNascita) ), 
						 (YEAR(DataNascita)),
						 ()
						) 
ORDER BY GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) );

--Tramite GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) ) posso anche filtrare.
--Se ad esempio volessi solo le righe con almeno un totali
SELECT CASE WHEN GROUPING_ID(YEAR(DataNascita)) = 0 
		    THEN CONVERT(VARCHAR(10),YEAR(DataNascita))
            ELSE 'Tutti' 
	   END AS Anno,
	   CASE WHEN GROUPING_ID(MONTH(DataNascita) ) = 0 
	        THEN MONTH(DataNascita)  
			ELSE 'Tutte' 
	   END AS Mese,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY GROUPING SETS ( (YEAR(DataNascita),MONTH(DataNascita) ), 
						 (YEAR(DataNascita)),
						 ()
						) 
HAVING GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) ) > 0
ORDER BY GROUPING_ID(YEAR(DataNascita),MONTH(DataNascita) );

-----------------------------------------------------
--Vediamo cosa succede utilizzando il raggruppamento
--predefinito cube
SELECT GROUPING_ID(YEAR(DataNascita)) AS Grouping_ID_Anno,
	   GROUPING_ID(RegioneResidenza) AS Grouping_ID_Regione,
	   GROUPING_ID(YEAR(DataNascita),RegioneResidenza) AS Grouping_ID_Anno_Regione,
       YEAR(DataNascita) AS Anno,
	   RegioneResidenza,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY CUBE (YEAR(DataNascita),RegioneResidenza  ) 
ORDER BY GROUPING_ID(YEAR(DataNascita),RegioneResidenza);

--la query con cube è equivalente a

SELECT GROUPING_ID(YEAR(DataNascita)) AS Grouping_ID_Anno,
	   GROUPING_ID(RegioneResidenza) AS Grouping_ID_Regione,
	   GROUPING_ID(YEAR(DataNascita),RegioneResidenza) AS Grouping_ID_Anno_Regione,
       YEAR(DataNascita) AS Anno,
	   RegioneResidenza,
	   COUNT(*) AS Numero
FROM   query.Clienti
GROUP BY GROUPING SETS ( (YEAR(DataNascita),RegioneResidenza),
						 (YEAR(DataNascita)),
						 (RegioneResidenza),
						 ()  )
ORDER BY GROUPING_ID(YEAR(DataNascita),RegioneResidenza);


--************************
--CLAUSOLA OUTPUT
--N.B. migliorabile usando il default
--************************
CREATE TABLE CorsoSQL.query.ClientiLog(
	IdCliente [varchar](50) NULL,
	Nome [varchar](50) NULL,
	Cognome [varchar](50) NULL,
	DataNascita [date] NULL,
	RegioneResidenza [varchar](50) NULL,
	TipologiaModifica varchar(50) NOT NULL,
	data_modifica datetime not null,
	system__user varchar(50) not null,
	current__USER varchar(50) not null
); 

DELETE FROM CorsoSQL.query.Clienti
	OUTPUT deleted.IdCliente, deleted.Nome,
		deleted.Cognome, deleted.DataNascita,
		deleted.RegioneResidenza, 'cancellazione',
		getdate(), SYSTEM_USER, current_USER
	INTO  CorsoSQL.query.ClientiLog (IdCliente,
						Nome, 
						Cognome,
						DataNascita,
						RegioneResidenza,
						TipologiaModifica ,
						data_modifica,
						system__user,
						current__USER) 
WHERE IdCliente = 1;



	
/************************
* TRANSAZIONI
************************/
/*ATTENZIONE: QUESTO CAPITOLO FA RIFERIMENTO ALLA GESTIONE
DELLE TRANSAZIONI TRAMITE SQL SERVER MANAGEMENT STUDIO.
LA SITUAZIONE CAMBIA SE CI SI CONNETTE A SQL SERVER
TRAMITE UN LINGUAGGIO DI BACK END E UNA RELATIVA LIBRERIA
*/

/*Esempio 1: transazione con rollback
lanciare un'istruzione alla volta*/
BEGIN TRAN

DELETE 
FROM  CorsoSQL.query.Prospect
WHERE IdProspect = 6;

--lanciare in questa e in un'altra sessione la query
SELECT * 
FROM query.Prospect; 

--eseguiamo una rollback
ROLLBACK

SELECT * 
FROM query.Prospect; 

/*Esempio 2: transazione con commit
lanciare un'istruzione alla volta*/
BEGIN TRAN

DELETE 
FROM  CorsoSQL.query.Prospect
WHERE IdProspect = 6;

SELECT * 
FROM   query.Prospect; 

--eseguiamo una commit
COMMIT TRAN

SELECT * 
FROM   query.Prospect; 


/*Commento:
dopo una begin tran, le operazioni di modifica del database 
NON sono definitive fino al momento in cui viene eseguita 
l'istruzione COMMIT.
Se invece della COMMIT è eseguita l'istruzione ROLLBACK, 
le modifiche fatte all'interno della transazione 
vengono annullate. 
L'aggiornamento di una tabella durante una transazione
impatta l'interazione sulla stessa tabella in altre sessioni
di SQL SERVER.
*/


/************************
* GESTIONI ERRORI
************************/

/*Esempio 3: blocco TRY-CATCH 
lanciare in un unico comando*/
BEGIN TRY
	
	--eseguito correttamente
	SELECT *
	FROM  query.Clienti
	WHERE IdCliente = 1;

	--genera un errore di conversione
	SELECT *
	FROM   query.Clienti
	WHERE  IdCliente = 'a';

	--NON VIENE ESEGUITO, perchè siamo all'interno di un blocco try e la query precedente
	--ha generato un errore
	SELECT *
	FROM   query.Clienti
	WHERE  IdCliente = 3;

END TRY
BEGIN CATCH
    
	--viene eseguito perchè all'interno del blocco try si è verificato un errore
	SELECT *
	FROM  query.Fatture;

END CATCH

/*Commento:
il blocco try/catch abilita la gestione degli errori su Sql server.
L'esecuzione del codice presente nel blocco try si interrompe al primo errore riscontrato.
Il codice successivo all'errore all'interno del blocco try NON viene eseguito.
Al suo posto sarà eseguito il codice presente nel blocco catch.
Se non ci sono errori nel blocco try, il codice presente nel blocco catch non viene eseguito*/

/*Esempio 4: blocco TRY-CATCH 
con THROW*/
BEGIN TRY
	
	--eseguito correttamente
	SELECT *
	FROM  query.Clienti
	WHERE IdCliente = 1;

	--genera un errore di conversione
	SELECT *
	FROM   query.Clienti
	WHERE  IdCliente = 'a';

	--NON VIENE ESEGUITO, perchè siamo all'interno di un blocco try e la query precedente
	--ha generato un errore
	SELECT *
	FROM   query.Clienti
	WHERE  IdCliente = 3;

END TRY
BEGIN CATCH
    
	--viene eseguito perchè all'interno del blocco try si è verificato un errore
	SELECT *
	FROM  query.Fatture;
	
	--interrompe l'esecuzione del blocco catch 
	--generando lo stesso errore che ha portato
	--l'interruzione del blocco try
	THROW;

	--non sarà eseguito per via del THROW precedente
	SELECT *
	FROM  query.Clienti;

END CATCH

/*COMMENTO: Per automatizzare le esecuzioni risulta fondamentale
utilizzare in modo congiunto gestione degli errori 
e transazioni perché 
1) non è possibile prevedere se Sql Server blocca l'esecuzione dopo
un errore oppure va avanti
2) in alcune situazioni sarebbe grave che solo uno dei due 
aggiornamenti programmati su un database vada a buon fine
(ad esempio tabella dei movimenti e dei saldi di un conto,
cancellazione dei dati di una tabella e ripopolazione)
*/

--Esempio 4: errore 1/0 non blocca l'esecuzione 

--Analizziamo i nomi dei primi tre clienti
SELECT * FROM query.Clienti WHERE IdCliente in (1,2,3)

BEGIN TRAN

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente = 1;

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente=2/0;

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente = 3;

SELECT * 
FROM  query.Clienti 
WHERE IdCliente in (1,2,3);

ROLLBACK

--Esempio 5: errore di conversione blocca l'esecuzione 
SELECT * 
FROM   query.clienti 
WHERE  IdCliente in (1,2,3);

BEGIN TRAN

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente = 1;

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente='a';

UPDATE CorsoSQL.query.Clienti 
SET    Nome='Raffaele'
WHERE  IdCliente = 3;

SELECT * 
FROM   query.clienti 
WHERE  IdCliente in (1,2,3);

ROLLBACK


--Esempio 7: utilizzo congiunto di try/catch e transazioni
BEGIN TRY

	SELECT *
	FROM   query.Clienti
	WHERE  IdCliente = 1;

    BEGIN TRAN
	/*aprendo la transazione all'interno del blocco try 
	e mettendo alla fine una commit, 
	quest'ultima verrà eseguita solo nel caso in cui 
	non si sia verificato nessun errore */

	UPDATE CorsoSQL.query.clienti 
	SET    Nome='Raffaele'
	WHERE  IdCliente = 1;

	UPDATE CorsoSQL.clienti 
	SET   Nome='Raffaele'
	WHERE IdCliente = 1/0;  /*la presenza di un errore generato 
	                          dalla divisione per 0, interromperà
							  l'esecuzione del codice nel blocco try
							  di conseguenza NON sarà eseguita la commit 
							  (che è buona norma scrive sempre come
							   l'ultima operazione del blocco try)
							  l'esecuzione passera al blocco catch */
    
	--non eseguita per via dell'errore precedente
	UPDATE CorsoSQL.query.clienti 
	SET    Nome='Raffaele'
	WHERE  IdCliente = 3;

	--non eseguita per via dell'errore precedente
	COMMIT TRAN;

END TRY
BEGIN CATCH
	/*se si è verificato un errore, verrà eseguita una rollback in 
	modo da tale da annullare le operazioni 
	già eseguite e che, a causa dell'errore, risulterebbero parziali */
	IF @@trancount>0 ROLLBACK;
	
	THROW; /*throw genera lo stesso errore che ha portato 
	         il codice a passare dal blocco try al blocco catch
		     throw termina l'esecuzione del codice nel blocco catch */
END CATCH
select * from query.clienti


--Nella prossima lezione vedremo delle tipologie di errori
--non gestite dal blocco TRY-CATCH


--Esempio 8: vediamo un primo caso non coperto dal try/catch
BEGIN TRY

 BEGIN TRAN
 
    DELETE FROM CorsoSQL.query.Clienti WHERE IdCliente = 1
    
	DELETE FROM CorsoSQL.query.TabellaCheNonEsiste
 
 COMMIT
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  THROW;

END CATCH

--Vediamo se ci sono transazioni aperte. La risposta è sì.
SELECT @@TRANCOUNT

--dobbiamo eseguire manualmente il rollback
ROLLBACK

/*Il TRY-CATCH non vede errori come quello generato dall'interrogare
una tabella che non esiste. La transazione dunque non è
stata ancora rollbackata ed è rimasta aperta. Per gestire anche questo
caso possiamo usare l'opzione SET XACT_ABORT ON che vale per l'intera
sessione. 

XACT_ABORT ON effettua (quasi) sempre il ROLLBACK di una 
transazione quando viene sollevato un errore. 

Inoltre con l'opzione di default SET XACT_ABORT OFF alcuni errori
nel blocco TRY potrebbero permetterci teoricamente di eseguire
comunque nel blocco CATCH il COMMIT della transazione (implementazione 
molto rara). Con XACT_ABORT ON (quasi) tutti gli errori
renderanno impossibile eseguire il COMMIT della transazione
nel blocco CATCH */

--lanciamo l'opzione SET XACT_ABORT ON
SET XACT_ABORT ON

--lanciamo ora la query
BEGIN TRY
 BEGIN TRAN
    DELETE FROM CorsoSQL.query.Clienti WHERE IdCliente = 1;
	DELETE FROM CorsoSQL.query.TabellaCheNonEsiste;
 COMMIT
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  THROW;
END CATCH

--vediamo se ci sono transazioni aperte. La risposta è NO
SELECT @@TRANCOUNT

--valutare se ripristinare il default XACT_ABORT OFF per la sessione 
SET XACT_ABORT OFF

--Esempio 9: vediamo un secondo caso non coperto dal try/catch
--interrompere l'esecuzione dopo qualche secondo tramite l'apposito
--tasto di SQL Server Management Studio
BEGIN TRY
 BEGIN TRAN
    DELETE FROM CorsoSQL.query.Clienti WHERE IdCliente = 1
	
	--la prossima istruzione genera un minuto di attesa
	WAITFOR DELAY '00:01'
	
 COMMIT
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  THROW;
END CATCH

--vediamo se ci sono transazioni aperte. La risposta è sì
SELECT @@TRANCOUNT;
rollback

--anche in questo caso riproviamo l'esperimento con
--xact_abort ON
SET XACT_ABORT ON
BEGIN TRY
 BEGIN TRAN
    DELETE FROM CorsoSQL.query.Clienti WHERE IdCliente = 1
	WAITFOR DELAY '00:01' 
	
 COMMIT
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  THROW;
END CATCH

select @@TRANCOUNT

--valutare se ripristinare il default XACT_ABORT OFF per la sessione 
SET XACT_ABORT OFF



/*Ecco un possibile template di stored procedure*/
CREATE/ALTER PROCEDURE <nomeprocedura>  --modifichiamo o creiamo la procedura assegnandole il nome
<dichiarazione variabili>      --dichiariamo i parametri
AS                               
BEGIN                          --begin relativo alla procedura
SET NOCOUNT ON             --eliminiamo i messaggi come "3 righe inserite"
SET XACT_ABORT ON          --per forzare il rollback in caso di errori, anche 
						   --se non gestiti dal try-catch
BEGIN TRY                  --apriamo il blocco try
	.....
	<logiche parziali>         --costruiamo TUTTE le logiche parziali 
	                           --utilizzando cte/tabelle temporanee/ecc..
	....
	BEGIN TRANSACTION          --se occorre aggiornare una o più tabelle fisiche, 
	                           --apriamo una transazione
	...
	<operazioni sul database>  --scriviamo le operazioni di insert/update/Delete
	...
	COMMIT                     --mettiamo subito prima della fine del 
	                           --blocco try una commit (verrà eseguita solo se non 
							   --si è verificato nessun errore) 
END TRY                        --chiudiamo il blocco try
BEGIN CATCH                    --apriamo il blocco catch
	IF @@trancount>0 ROLLBACK; --effettuiamo il rollback della transazione aperta
	<gestione errore>          --creiamo messagi di errore/inviamo una mail 
	THROW;                     --restituiamo l'errore fuori
                               --dalla stored procedure
END CATCH    				   --chiudiamo il blocco catch
END							   --chiudiamo la procedura

	
	
/*********************************
* JSON
**********************************/
DECLARE @json_string VARCHAR(MAX) = '
{"id_fattura":1,
"nome_prodotto":"Prodotto1",
"tipologia":"A",
"importo":120.12,
"data_fattura":"2018-05-01"}';


SELECT *
FROM   OpenJson(@json_string) AS f;


SELECT *
FROM   OpenJson(@json_string)
WITH (
  id_fattura INT '$.id_fattura',
  nome_prodotto VARCHAR(50) '$.nome_prodotto',
  tipologia VARCHAR(50) '$.tipologia',
  importo DECIMAL(18,4) '$.importo',
  data_fattura DATE '$.data_fattura'
) AS f;
--N.B. Attenzione al datetime. Se ad esempio SELECT @@LANGUAGE restituisce
--italian, valori come 2020-01-05 (con il trattito come separatore)
-- sarebbero letti come 1 maggio 2020 in una colonna datetime

--json più complessi
DECLARE @json_string VARCHAR(max) = '
{"id_fattura":1,
"cliente":{"id_cliente": 2,
           "nome":"nicola",
            "cognome":"Iantomasi"},
"tipologie":["A","V"]
}';

SELECT *
FROM   OpenJson(@json_string)
WITH (
 id_fattura INT '$.id_fattura',
 cliente NVARCHAR(MAX) '$.cliente' AS JSON,
 tipologie NVARCHAR(MAX) '$.tipologie' AS JSON
) AS f;

SELECT 
 f.id_fattura,
 f.id_cliente,
 f.nome,
 f.cognome,
 t.tipologia
FROM   OpenJson(@json_string)
WITH (
 id_fattura INT '$.id_fattura',
 id_cliente INT '$.cliente.id_cliente',
 nome VARCHAR(50) '$.cliente.nome',
 cognome VARCHAR(50) '$.cliente.cognome',
 tipologia NVARCHAR(MAX) '$.tipologie' AS JSON
) AS f 
OUTER APPLY 
OpenJson(f.tipologia)
WITH (
 tipologia VARCHAR(20) '$') AS  t;



--Trasformare una tabella in un JSON
SELECT TOP 2 
  IdFattura, 
  Importo AS [DatiContabili.importo],
  Iva AS [DatiContabili.iva] 
FROM query.Fatture 
FOR JSON PATH;


SELECT
  c.IdCliente,
  (SELECT IdFattura ,
          Importo
   FROM Fatture AS f
   WHERE f.IdCliente = c.IdCliente
   FOR JSON PATH) AS Fatture
FROM Clienti AS c
FOR JSON PATH;


/***************
String agg
****************/

SELECT  
   IdFattura,
   STRING_AGG(IdProdotto, 
              ';') AS Prodotti
FROM    query.FattureProdotti
GROUP BY IdFattura;

--aggiungiamo un ordinamento
SELECT  
   IdFattura,
   STRING_AGG(IdProdotto, 
              ';') 
		WITHIN GROUP (ORDER BY IdProdotto desc) AS Prodotti
FROM    query.FattureProdotti
GROUP BY IdFattura;

--gestione null
SELECT IdFattura,
   STRING_AGG(Sconto,
              ';') WITHIN GROUP (ORDER BY idprodotto ) ,
	STRING_AGG(isnull(Sconto,-999),
              ';') WITHIN GROUP (ORDER BY idprodotto ) ,
	STRING_AGG(isnull(cast(Sconto as varchar(255)),''),
              ';') 
		WITHIN GROUP (ORDER BY idprodotto ) 
FROM query.FattureProdotti
WHERE IdFattura = 277
GROUP BY idfattura;


--************************
--Chiarimenti su Union ALL
--************************

--restituisce un errore
select 1 as campo2
	union all
select 'a' as campo1 

--restituisce un errore
select 'a' as campo1
	union all
select 1 as campo2 

--converte la stringa '1' nel numero 1
select 5 as campo2
	union all
select '1' as campo1 

--entrambi i campi hanno lo stesso formato stringa
select 'a' as campo2 
	union all
select '1' as campo1 

--************************
--idem per case WHEN
--************************
select case when 1=1 then 'a'
            else 2
	    end;



--************************
--IS NULL E COALESCE 1
--************************
DECLARE
  @x AS VARCHAR(3) = null,
  @y AS VARCHAR(10) = 'abcdefg';

SELECT COALESCE(@x, @y) AS [COALESCE], ISNULL(@x, @y) AS [ISNULL];

--************************
--IS NULL E COALESCE 2
--************************
select coalesce( (select count(*) from clienti) ,1);

select isnull( (select count(*) from clienti) ,1);



--************************
--DATE STRANE
--************************
SET LANGUAGE 'italian'  
SELECT MONTH(cast(
				'2020-03-01 15:12:33' as datetime));

SET LANGUAGE british
SELECT CAST('2003-02-28' AS DATETIME);




/*************
MERGE
*************/
https://www.mssqltips.com/sqlservertip/3074/use-caution-with-sql-servers-merge-statement/


/**************************
Cursori e IA
**************************/
/*Script per creare dataset Iris

acknowledgements
Dua,D. and Graff,C. (2019). UCI Machine Learning Repository [http://archive.ics.uci.edu/ml]. Irvine,CA: University of California,School of Information and Computer Science.
*/
/*


CREATE TABLE   CorsoSQL.query.IrisTraining  (
	Rownumber  INT NOT NULL,
	  sepal_length decimal(18,2) NOT NULL,
	  sepal_width  decimal(18,2) NOT NULL,
	  petal_length decimal(18,2) NOT NULL,
	  petal_width  decimal(18,2) NOT NULL,
	  class varchar(50) NOT NULL
);  

INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('41',CAST(5.00 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('42',CAST(4.50 AS Decimal(18,2)),CAST(2.30 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('43',CAST(4.40 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('44',CAST(5.00 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.60 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('45',CAST(5.10 AS Decimal(18,2)),CAST(3.80 AS Decimal(18,2)),CAST(1.90 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('46',CAST(4.80 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('47',CAST(5.10 AS Decimal(18,2)),CAST(3.80 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('48',CAST(4.60 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('49',CAST(5.30 AS Decimal(18,2)),CAST(3.70 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('50',CAST(5.00 AS Decimal(18,2)),CAST(3.30 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('11',CAST(5.40 AS Decimal(18,2)),CAST(3.70 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('12',CAST(4.80 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('13',CAST(4.80 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('14',CAST(4.30 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.10 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa'); 
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('15',CAST(5.80 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('16',CAST(5.70 AS Decimal(18,2)),CAST(4.40 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('17',CAST(5.40 AS Decimal(18,2)),CAST(3.90 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('18',CAST(5.10 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('19',CAST(5.70 AS Decimal(18,2)),CAST(3.80 AS Decimal(18,2)),CAST(1.70 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('20',CAST(5.10 AS Decimal(18,2)),CAST(3.80 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('21',CAST(5.40 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.70 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('22',CAST(5.10 AS Decimal(18,2)),CAST(3.70 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('23',CAST(4.60 AS Decimal(18,2)),CAST(3.60 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('24',CAST(5.10 AS Decimal(18,2)),CAST(3.30 AS Decimal(18,2)),CAST(1.70 AS Decimal(18,2)),CAST(0.50 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('25',CAST(4.80 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.90 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('26',CAST(5.00 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('27',CAST(5.00 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('28',CAST(5.20 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('29',CAST(5.20 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('30',CAST(4.70 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('31',CAST(4.80 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('32',CAST(5.40 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('33',CAST(5.20 AS Decimal(18,2)),CAST(4.10 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('34',CAST(5.50 AS Decimal(18,2)),CAST(4.20 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('35',CAST(4.90 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('36',CAST(5.00 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('37',CAST(5.50 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('38',CAST(4.90 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('39',CAST(4.40 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('40',CAST(5.10 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('51',CAST(7.00 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(4.70 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('52',CAST(6.40 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('53',CAST(6.90 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(4.90 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('54',CAST(5.50 AS Decimal(18,2)),CAST(2.30 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('55',CAST(6.50 AS Decimal(18,2)),CAST(2.80 AS Decimal(18,2)),CAST(4.60 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('56',CAST(5.70 AS Decimal(18,2)),CAST(2.80 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('57',CAST(6.30 AS Decimal(18,2)),CAST(3.30 AS Decimal(18,2)),CAST(4.70 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('58',CAST(4.90 AS Decimal(18,2)),CAST(2.40 AS Decimal(18,2)),CAST(3.30 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('59',CAST(6.60 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.60 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('60',CAST(5.20 AS Decimal(18,2)),CAST(2.70 AS Decimal(18,2)),CAST(3.90 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('61',CAST(5.00 AS Decimal(18,2)),CAST(2.00 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('62',CAST(5.90 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.20 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('63',CAST(6.00 AS Decimal(18,2)),CAST(2.20 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('64',CAST(6.10 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.70 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('65',CAST(5.60 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(3.60 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('66',CAST(6.70 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(4.40 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('67',CAST(5.60 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('68',CAST(5.80 AS Decimal(18,2)),CAST(2.70 AS Decimal(18,2)),CAST(4.10 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('69',CAST(6.20 AS Decimal(18,2)),CAST(2.20 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('70',CAST(5.60 AS Decimal(18,2)),CAST(2.50 AS Decimal(18,2)),CAST(3.90 AS Decimal(18,2)),CAST(1.10 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('71',CAST(5.90 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(4.80 AS Decimal(18,2)),CAST(1.80 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('72',CAST(6.10 AS Decimal(18,2)),CAST(2.80 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('73',CAST(6.30 AS Decimal(18,2)),CAST(2.50 AS Decimal(18,2)),CAST(4.90 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('74',CAST(6.10 AS Decimal(18,2)),CAST(2.80 AS Decimal(18,2)),CAST(4.70 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('75',CAST(6.40 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.30 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('76',CAST(6.60 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.40 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('77',CAST(6.80 AS Decimal(18,2)),CAST(2.80 AS Decimal(18,2)),CAST(4.80 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('78',CAST(6.70 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(5.00 AS Decimal(18,2)),CAST(1.70 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('79',CAST(6.00 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('80',CAST(5.70 AS Decimal(18,2)),CAST(2.60 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('81',CAST(5.50 AS Decimal(18,2)),CAST(2.40 AS Decimal(18,2)),CAST(3.80 AS Decimal(18,2)),CAST(1.10 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('82',CAST(5.50 AS Decimal(18,2)),CAST(2.40 AS Decimal(18,2)),CAST(3.70 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('83',CAST(5.80 AS Decimal(18,2)),CAST(2.70 AS Decimal(18,2)),CAST(3.90 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('84',CAST(6.00 AS Decimal(18,2)),CAST(2.70 AS Decimal(18,2)),CAST(5.10 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('95',CAST(5.60 AS Decimal(18,2)),CAST(2.70 AS Decimal(18,2)),CAST(4.20 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('96',CAST(5.70 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.20 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('97',CAST(5.70 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.20 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('98',CAST(6.20 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(4.30 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTraining (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('99',CAST(5.10 AS Decimal(18,2)),CAST(2.50 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.10 AS Decimal(18,2)),'Iris versicolor');

CREATE TABLE CorsoSQL.query.IrisTest(
	Rownumber INT NOT NULL,
	sepal_length decimal(18,2) NOT NULL,
	sepal_width decimal(18,2) NOT NULL,
	petal_length decimal(18,2) NOT NULL,
	petal_width decimal(18,2) NOT NULL,
	class varchar(50) NOT NULL
); 


INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('1',CAST(4.00 AS Decimal(18,2)),CAST(3.50 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('2',CAST(4.20 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('3',CAST(4.70 AS Decimal(18,2)),CAST(3.20 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('4',CAST(4.60 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('5',CAST(5.00 AS Decimal(18,2)),CAST(3.60 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('6',CAST(5.40 AS Decimal(18,2)),CAST(3.90 AS Decimal(18,2)),CAST(1.70 AS Decimal(18,2)),CAST(0.40 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('7',CAST(4.60 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.30 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('8',CAST(5.00 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('9',CAST(4.40 AS Decimal(18,2)),CAST(2.90 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),CAST(0.20 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('10',CAST(4.90 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),CAST(0.10 AS Decimal(18,2)),'Iris setosa');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('90',CAST(5.50 AS Decimal(18,2)),CAST(2.50 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('91',CAST(5.50 AS Decimal(18,2)),CAST(2.60 AS Decimal(18,2)),CAST(4.40 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('92',CAST(6.10 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.60 AS Decimal(18,2)),CAST(1.40 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('93',CAST(5.80 AS Decimal(18,2)),CAST(2.60 AS Decimal(18,2)),CAST(4.00 AS Decimal(18,2)),CAST(1.20 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class) VALUES ('94',CAST(5.00 AS Decimal(18,2)),CAST(2.30 AS Decimal(18,2)),CAST(3.30 AS Decimal(18,2)),CAST(1.00 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('85',CAST(5.40 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('86',CAST(6.00 AS Decimal(18,2)),CAST(3.40 AS Decimal(18,2)),CAST(4.50 AS Decimal(18,2)),CAST(1.60 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('87',CAST(6.70 AS Decimal(18,2)),CAST(3.10 AS Decimal(18,2)),CAST(4.70 AS Decimal(18,2)),CAST(1.50 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('88',CAST(6.30 AS Decimal(18,2)),CAST(2.30 AS Decimal(18,2)),CAST(4.40 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
INSERT INTO CorsoSQL.query.IrisTest (Rownumber,sepal_length,sepal_width,petal_length,petal_width,class  ) VALUES ('89',CAST(5.60 AS Decimal(18,2)),CAST(3.00 AS Decimal(18,2)),CAST(4.10 AS Decimal(18,2)),CAST(1.30 AS Decimal(18,2)),'Iris versicolor');
*/


SELECT * FROM query.IrisTraining;
SELECT * FROM query.IrisTest;

ALTER TABLE CorsoSQL.query.IrisTraining ADD Bias DECIMAL(18,2);
ALTER TABLE CorsoSQL.query.IrisTest ADD Bias DECIMAL(18,2);

UPDATE CorsoSQL.query.IrisTraining 
SET Bias = 1;

UPDATE CorsoSQL.query.IrisTest 
SET Bias = 1;

SELECT * FROM query.IrisTraining;
SELECT * FROM query.IrisTest;

/*Creiamo una procedura per il pre-processing*/
CREATE PROCEDURE query.pre_processing
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
BEGIN TRY
	DECLARE @media_sepal_length DECIMAL(18,6);
    DECLARE @media_sepal_width DECIMAL(18,6);
    DECLARE @media_petal_length DECIMAL(18,6);
    DECLARE @media_petal_width DECIMAL(18,6);
	DECLARE @std_sepal_length DECIMAL(18,6);
    DECLARE @std_sepal_width DECIMAL(18,6);
    DECLARE @std_petal_length DECIMAL(18,6);
    DECLARE @std_petal_width DECIMAL(18,6);
    
    SELECT @media_sepal_length = AVG(sepal_length), 
		@media_sepal_width = AVG(sepal_width), 
		@media_petal_length = AVG(petal_length),
		@media_petal_width = AVG(petal_width),
		@std_sepal_length = STDEVP(sepal_length), 
		@std_sepal_width = STDEVP(sepal_width), 
		@std_petal_length = STDEVP(petal_length),
		@std_petal_width = STDEVP(petal_width)
	FROM query.IrisTraining;
    
    BEGIN TRAN
		UPDATE CorsoSQL.query.IrisTraining
		SET  sepal_length = (sepal_length-@media_sepal_length)/@std_sepal_length,
			 sepal_width = (sepal_width-@media_sepal_width)/@std_sepal_width,
			 petal_length = (petal_length-@media_petal_length)/@std_petal_length,
			 petal_width = (petal_width-@media_petal_width)/@std_petal_width;
			 
		UPDATE CorsoSQL.query.IrisTest
		SET  sepal_length = (sepal_length-@media_sepal_length)/@std_sepal_length,
			 sepal_width = (sepal_width-@media_sepal_width)/@std_sepal_width,
			 petal_length = (petal_length-@media_petal_length)/@std_petal_length,
			 petal_width = (petal_width-@media_petal_width)/@std_petal_width;

		UPDATE CorsoSQL.query.IrisTraining
		SET class = 1
		WHERE class = 'Iris setosa';
		
		UPDATE CorsoSQL.query.IrisTraining
		SET class = -1
		WHERE class = 'Iris versicolor';   
		
		UPDATE CorsoSQL.query.IrisTest
		SET class = 1
		WHERE class = 'Iris setosa';
		
		UPDATE CorsoSQL.query.IrisTest
		SET class = -1
		WHERE class = 'Iris versicolor'; 
		
		COMMIT
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK;

		THROW
	END CATCH
END

/*Eseguiamo la procedura*/
EXEC query.pre_processing;


SELECT * FROM query.IrisTraining;
SELECT * FROM query.IrisTest;


CREATE TABLE CorsoSQL.QUERY.w (w0 decimal(18,4), 
	w1 decimal(18,4), 
    w2 decimal(18,4), 
    w3 decimal(18,4), 
    w4 decimal(18,4));
    

/*Creiamo la procedura di Machine Learning*/
CREATE OR ALTER PROCEDURE query.Perceptron
 @epoche INT = 10, 
 @eta DECIMAL(18,4) = 0.1
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON

BEGIN TRY
	/*inizializziamo il vettore w*/
	CREATE TABLE #w (w0 decimal(18,4), 
		w1 decimal(18,4), 
		w2 decimal(18,4), 
		w3 decimal(18,4), 
		w4 decimal(18,4));
		
	INSERT INTO #w(w0, w1, w2, w3, w4)
	VALUES(0,0,0,0,0);

	/*creiamo una variabile I per iterare il procedimento un certo numero di volte*/
	DECLARE @I INT = 1

	/*ciclo while*/
	WHILE @I < @epoche
	BEGIN
	
		DECLARE @predizione DECIMAL(18,2);
		DECLARE @class DECIMAL(18,2);
		DECLARE @RowNumber INT;
		DECLARE @sepal_length DECIMAL(18,4);
		DECLARE @sepal_width DECIMAL(18,4);
		DECLARE @petal_length DECIMAL(18,4);
		DECLARE @petal_width DECIMAL(18,4);
		DECLARE @bias DECIMAL(18,4);

		/*dichiariamo un cursore contenente le righe del dataset di Training
		ordinate in modo randomico*/
		DECLARE cursore CURSOR
		FOR SELECT RowNumber,sepal_length,sepal_width,petal_length,petal_width,bias,class
		    FROM query.IrisTraining
		    ORDER BY NEWID();

		/*apriamo il cursore */
		OPEN cursore;

		/*inseriamo il valore corrente del cursore nelle variabili*/
		FETCH NEXT FROM cursore 
		INTO @RowNumber, @sepal_length, @sepal_width, @petal_length, @petal_width, @bias, @class;
		
		/*ciclo while sulle righe del cursore*/
		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			/*calcoliamo la predizione */			
			SELECT @predizione = 
				CASE WHEN @sepal_length * w0 + 
						  @sepal_width * w1 + 
						  @petal_length* w2 + 
						  @petal_width* w3 + 
						  @bias * w4 > 0
						THEN 1 
						ELSE -1 
				END
			FROM #w;

			/*aggiornamento il vettore w*/
			UPDATE #w
			SET w0 = w0 + @eta*(@class-@predizione)*@sepal_length,
				w1 = w1 + @eta*(@class-@predizione)*@sepal_width,
				w2 = w2 + @eta*(@class-@predizione)*@petal_length,
				w3 = w3 + @eta*(@class-@predizione)*@petal_width,
				w4 = w4 + @eta*(@class-@predizione)*@bias

			/*valorizziamo le variabili con la riga seguente del cursore*/
			FETCH NEXT FROM cursore 
			INTO @RowNumber, @sepal_length, @sepal_width, @petal_length, @petal_width, @bias, @class;
		END

		/*chiudiamo e deallochiamo il cursore*/
		CLOSE cursore
		DEALLOCATE cursore

		/*incrementiamo il numero di iterazioni*/
		SET @I = @I + 1
	END
	BEGIN TRAN
		DELETE FROM CorsoSQL.QUERY.W;

		INSERT INTO CorsoSQL.QUERY.W(w0,w1,w2,w3,w4)
		SELECT w0,w1,w2,w3,w4
		FROM   #w;

	COMMIT
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK;

	THROW
END CATCH
END

/*Eseguiamo la procedura*/
EXEC query.Perceptron;


/*Guardiamo il vettore delle predizioni*/
SELECT * 
FROM   w;


/*Calcoliamo le predizioni sui dati di test*/
SELECT IrisTest.*, 
	CASE WHEN sepal_length * w0 + 
			  sepal_width * w1 + 
			  petal_length* w2 + 
			  petal_width* w3 + 
			 bias * w4 > 0
		 THEN 1 
		 ELSE -1 
	END AS Predizione
FROM   IrisTest
CROSS JOIN W;



with 
c1 as (
	select ts.rownumber as id_test,
		tr.rownumber as id_training,
		tr.class as class_training,
		SQRT(
			POWER(TS.sepal_length-TR.sepal_length,2)+
			POWER(TS.sepal_width-TR.sepal_width,2)+
			POWER(TS.petal_length-TR.petal_length,2)+
			POWER(TS.petal_width-TR.petal_width,2) ) AS Distanza,
		ts.class as class_per_verifica
	from iristest as ts 
	cross join IrisTraining as tr),
c2 as (
	SELECT *,
		row_number() over(partition by id_test
						  order by Distanza asc) as rn
	FROM   c1),
c3 as (
	SELECT * 
	FROM   c2
	WHERE  rn <= 5) ,
	c4 as (
	SELECT ID_TEST,	
		MAX(class_per_verifica) AS class_per_verifica,
		sum(iif(class_training = 'Iris setosa', 1,0))  AS Numero_setosa,
		sum(iif(class_training = 'Iris versicolor', 1, 0))  AS Numero_versicolor
	FROM   C3
	GROUP BY ID_TEST
		)
SELECT Id_test, 
	class_per_verifica, 
	iif(numero_setosa > Numero_versicolor, 'Iris setosa', 'Iris versicolor') as class_predetta
FROM   C4



