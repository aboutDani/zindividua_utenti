
Report Estrazione Anagrafica Tecnici SAP [creato in autonomia con linguaggio ABAP]

Questo report ABAP estrae l'elenco degli utenti SAP attivi associati a uno specifico ruolo tecnico, recuperando le relative informazioni anagrafiche (CID, Nome, Cognome ed E-mail) da HR, ed esporta i dati in un file locale in formato .csv.

🛠️ Schermata di Selezione (Selection Screen)

Campo	Parametro SAP	Tipo	Obbligatorio	Valore di Default / Note
Codice utente SAP	USR02-BNAME	Selezione Multipla (SELECT-OPTIONS)	No	Facoltativo
Data di riferimento	SY-DATUM	Singolo (PARAMETERS)	Sì	Data odierna (SY-DATUM)
Ruolo utente	AGR_USERS-AGR_NAME	Singolo (PARAMETERS)	Sì	YS_ISUTECNICI_MSV
Percorso e nome file	RLGRAP-FILENAME	Download Locale (PARAMETERS)	Sì	F4 abilitato per ricerca percorso locale

⚙️ Logica di Elaborazione (Processing Logic)

Il flusso di estrazione dati segue i passaggi sequenziali descritti di seguito:

1. Verifica Utenti Attivi (USR02)

Se popolato il filtro utenti, seleziona dalla tabella USR02 dove:
• BNAME IN Codice utente SAP (in selezione)
• GLTGB >= Data in selezione (Verifica utente non scaduto)

2. Verifica Associazione Ruolo (AGR_USERS)

Con l'elenco dei codici utente (BNAME) filtrati, accedi alla tabella AGR_USERS:
• UNAME = USR02-BNAME
• AGR_NAME = Ruolo utente in selezione
• TO_DAT >= Data in selezione (Verifica ruolo ancora valido)
⚠️ Nota: I record estratti vengono filtrati rimuovendo i duplicati sul campo AGR_USERS-UNAME.

3. Recupero CID / Matricola (PA0105)

Per ogni utente univoco ottenuto, accedi alla tabella PA0105 (Infotype 0105, Subtype 0001 - Sistema SAP):
• SUBTY = '0001'
• USRID = AGR_USERS-UNAME
• ENDDA >= Data in selezione
• Output: Estrazione del CID del dipendente dal campo PA0105-PERNR.

4. Recupero Dati Anagrafici (PA0002)

Utilizzando il CID (PERNR) individuato, accedi alla tabella PA0002 (Infotype 0002 - Dati Personali):
• PERNR = PA0105-PERNR
• ENDDA >= Data in selezione
• Output: Estrazione di PA0002-NACHN (Cognome) e PA0002-VORNA (Nome).

5. Recupero Indirizzo E-mail (PA0105)

Sempre tramite il CID (PERNR), effettua un secondo accesso a PA0105 (Subtype 0010 - E-Mail):
• PERNR = CID in elaborazione
• SUBTY = '0010' (Nota: corretto logicamente rispetto allo standard SAP per l'e-mail, originariamente indicato come 0001)
• Data in selezione COMPRESA TRA PA0105-BEGDA E PA0105-ENDDA
• Output: Estrazione dell'indirizzo e-mail dal campo PA0105-USRLONG (o USRIL).

📊 Tracciato di Output (File .csv)

Il file viene generato localmente sul PC dell'utente. I campi sono separati dal carattere punto e virgola (;).

Posizione	Campo GitHub / CSV	Descrizione	Tabella / Campo SAP
1	Cognome	Cognome dell'utente	PA0002-NACHN
2	Nome	Nome dell'utente	PA0002-VORNA
3	username	Identificativo utente (HDA)	USR02-BNAME
4	e-mail	Indirizzo di posta elettronica	PA0105-USRIL / USRLONG
5	CID	Codice Identificativo (Matricola)	PA0105-PERNR
