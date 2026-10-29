*&---------------------------------------------------------------------*
*& Report ZINDIVIDUA_UTENTI
*&---------------------------------------------------------------------*
REPORT zindividua_utenti.

" Tabelle
TABLES: usr02, agr_users.

" Schermo di selezione
SELECTION-SCREEN BEGIN OF BLOCK blocco1 WITH FRAME TITLE TEXT-001.
SELECT-OPTIONS: s_bname FOR usr02-bname.
PARAMETERS: p_data  TYPE sy-datum OBLIGATORY DEFAULT sy-datum.
PARAMETERS: p_ruolo TYPE agr_users-agr_name OBLIGATORY DEFAULT 'YS_ISUTECNICI_MSV'.
PARAMETERS: p_file  TYPE string OBLIGATORY. "DEFAULT 'C:\temp\utenti_SAP.csv'.
SELECTION-SCREEN END OF BLOCK blocco1.

TYPES: BEGIN OF ty_output,
         nachn      TYPE pa0002-nachn,
         vorna      TYPE pa0002-vorna,
         bname      TYPE string, "usr02-bname (cambiato per gestire oltre 12 caratteri
         usrid_long TYPE pa0105-usrid_long,
         pernr      TYPE pa0105-pernr,
       END OF ty_output.

DATA: lt_output TYPE STANDARD TABLE OF ty_output,
      ls_output TYPE ty_output.

" tasto sfoglia del file

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.

  DATA: lt_file_table  TYPE filetable,
        ls_file_table  TYPE file_table,
        lv_rc          TYPE i,
        lv_file_string TYPE string.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = 'Seleziona dove salvare il file CSV'
      default_filename        = 'utenti_SAP.csv'
      initial_directory       = 'C:\temp\'
      file_filter             = 'File CSV (*.csv)|*.csv|Tutti i file (*.*)|*.*'
    CHANGING
      file_table              = lt_file_table
      rc                      = lv_rc
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5.

  IF sy-subrc = 0 AND lv_rc > 0.
    READ TABLE lt_file_table INTO ls_file_table INDEX 1.
    IF sy-subrc = 0.
      lv_file_string = ls_file_table-filename.
      p_file = lv_file_string.
    ENDIF.
  ENDIF.


* LOGICA DI ELABORAZIONE PRINCIPALE
START-OF-SELECTION.

  TYPES: BEGIN OF ty_agr_users,
           uname TYPE agr_users-uname,
         END OF ty_agr_users.

  DATA: lt_utenti_ruolo TYPE STANDARD TABLE OF ty_agr_users,
        ls_ruolo        TYPE ty_agr_users.

  "tabella dei ruoli con i filtri dello schermo
  SELECT uname
    FROM agr_users
    INTO TABLE lt_utenti_ruolo
    WHERE uname    IN s_bname   " Filtra per l'utente inserito (es. VAIOTTIM)
      AND agr_name = p_ruolo    " Filtra per il ruolo inserito (es. Z_SYCLO)
  AND to_dat   >= p_data.

  IF lt_utenti_ruolo IS INITIAL.
    MESSAGE 'Nessun utente trovato con il ruolo e i filtri inseriti.' TYPE 'I'.
    EXIT.
  ENDIF.

  " Elimino i duplicati dalla lista dei ruoli
  SORT lt_utenti_ruolo BY uname.
  DELETE ADJACENT DUPLICATES FROM lt_utenti_ruolo COMPARING uname.


  "Esclude gli utenti scaduti e gestisce quelli con campo vuoto
  TYPES: BEGIN OF ty_usr02,
           bname TYPE usr02-bname,
         END OF ty_usr02.

  DATA: lt_utenti_attivi TYPE STANDARD TABLE OF ty_usr02,
        ls_usr02_check   TYPE ty_usr02.

  SELECT bname
    FROM usr02
    INTO TABLE lt_utenti_attivi
    FOR ALL ENTRIES IN lt_utenti_ruolo
    WHERE bname = lt_utenti_ruolo-uname
  AND ( gltgb >= p_data OR gltgb = '00000000' ). "se è vuoto lo considero attivo!

  SORT lt_utenti_attivi BY bname.

  LOOP AT lt_utenti_ruolo INTO ls_ruolo.
    DATA: lv_uname_clean TYPE usr02-bname.
    lv_uname_clean = ls_ruolo-uname.
    CONDENSE lv_uname_clean.

    READ TABLE lt_utenti_attivi INTO ls_usr02_check
      WITH KEY bname = lv_uname_clean BINARY SEARCH.
    IF sy-subrc <> 0.
      DELETE lt_utenti_ruolo WHERE uname = ls_ruolo-uname.
    ENDIF.
  ENDLOOP.

  IF lt_utenti_ruolo IS INITIAL.
    MESSAGE 'Gli utenti trovati non sono attivi nel sistema (USR02).' TYPE 'I'.
    EXIT.
  ENDIF.
  "--------------------------------------------------------------------*

  " Tabella PA0105
  TYPES: BEGIN OF ty_pa0105_cid,
           pernr TYPE pa0105-pernr,
           usrid TYPE pa0105-usrid,
         END OF ty_pa0105_cid.

  DATA: lt_lista_cid TYPE STANDARD TABLE OF ty_pa0105_cid.

  TYPES: BEGIN OF ty_compatibile,
           usrid TYPE pa0105-usrid,
         END OF ty_compatibile.

  DATA: lt_utenti_compatibili TYPE STANDARD TABLE OF ty_compatibile,
        ls_compatibile        TYPE ty_compatibile.

  " Convertiamo lo username per farlo funzionare con la PA0105 (campo lungo 30)
  LOOP AT lt_utenti_ruolo INTO ls_ruolo.
    ls_compatibile-usrid = ls_ruolo-uname.
    " Pulire da spazi strani e fortura maiuscolo
    CONDENSE ls_compatibile-usrid.
    TRANSLATE ls_compatibile-usrid TO UPPER CASE.
    APPEND ls_compatibile TO lt_utenti_compatibili.
  ENDLOOP.

  SORT lt_utenti_compatibili BY usrid.

  " Accesso alla PA0105 per trovare il CID (Matricola)
  SELECT pernr usrid
    FROM pa0105
    INTO TABLE lt_lista_cid
    FOR ALL ENTRIES IN lt_utenti_compatibili
    WHERE subty = '0001'
      AND usrid = lt_utenti_compatibili-usrid
  AND endda >= p_data.
  IF lt_lista_cid IS INITIAL.
    MESSAGE 'Nessun CID (Matricola) associato agli utenti selezionati.' TYPE 'I'.
    EXIT.
  ENDIF.

  "----------------------------------------------------------------

  " struttura per salvare i dati anagrafici estratti
  TYPES: BEGIN OF ty_pa0002_anag,
           pernr TYPE pa0002-pernr, " CID
           vorna TYPE pa0002-vorna, " Nome
           nachn TYPE pa0002-nachn, " Cognome
         END OF ty_pa0002_anag.

  DATA: lt_anagrafica TYPE STANDARD TABLE OF ty_pa0002_anag.

  " Recupero di Nome e Cognome usando la lista dei CID
  SELECT pernr vorna nachn
    FROM pa0002
    INTO TABLE lt_anagrafica
    FOR ALL ENTRIES IN lt_lista_cid
    WHERE pernr = lt_lista_cid-pernr
  AND endda >= p_data.

  " struttura per salvare l'email associata al CID
  TYPES: BEGIN OF ty_pa0105_email,
           pernr      TYPE pa0105-pernr,
           usrid_long TYPE pa0105-usrid_long, " Campo e-mail
         END OF ty_pa0105_email.

  DATA: lt_email TYPE STANDARD TABLE OF ty_pa0105_email.

  " Recupero dell'email usando la lista dei CID
  SELECT pernr usrid_long
    FROM pa0105
    INTO TABLE lt_email
    FOR ALL ENTRIES IN lt_lista_cid
    WHERE pernr = lt_lista_cid-pernr
      AND subty = '0010'
      AND begda <= p_data
  AND endda >= p_data.

"---------------------
" nuova parte gestione username con tabella zhr_hda_user
  TYPES: BEGIN OF ty_zhr_hda_user,
           pernr TYPE zhr_hda_user-pernr,
           usrid TYPE zhr_hda_user-usrid,
         END OF ty_zhr_hda_user.

  DATA: lt_hda_user TYPE STANDARD TABLE OF ty_zhr_hda_user,
        ls_hda_temp TYPE ty_zhr_hda_user.

 SELECT pernr usrid
    FROM zhr_hda_user
    INTO TABLE lt_hda_user
    FOR ALL ENTRIES IN lt_lista_cid
    WHERE pernr = lt_lista_cid-pernr.

  SORT lt_hda_user BY pernr.
"---------------------------


  " Strutture per lettura dati
  DATA: ls_cid_temp   LIKE LINE OF lt_lista_cid,
        ls_anag_temp  LIKE LINE OF lt_anagrafica,
        ls_email_temp LIKE LINE OF lt_email.

  " Il ciclo principale parte dagli utenti che hanno superato il filtro del ruolo
  LOOP AT lt_utenti_ruolo INTO ls_ruolo.

    " username
    READ TABLE lt_lista_cid INTO ls_cid_temp
      WITH KEY usrid = ls_ruolo-uname.

    IF sy-subrc = 0.
      ls_output-bname = ls_ruolo-uname.       " Username
      ls_output-pernr = ls_cid_temp-pernr.     " CID


" new------------------------
" Verifichiamo se il CID è presente in zhr_hda_user
      READ TABLE lt_hda_user INTO ls_hda_temp
        WITH KEY pernr = ls_output-pernr BINARY SEARCH.
      IF sy-subrc = 0.
        " Se presente, prendo il nome corretto da qui anziché lato SAP!
        ls_output-bname = ls_hda_temp-usrid.
      ENDIF.
"------------------------------



      " Nome e Cognome
      READ TABLE lt_anagrafica INTO ls_anag_temp
        WITH KEY pernr = ls_output-pernr.
      IF sy-subrc = 0.
        ls_output-vorna = ls_anag_temp-vorna. " Nome
        ls_output-nachn = ls_anag_temp-nachn. " Cognome
      ENDIF.

      " indirizzo e-mail
      READ TABLE lt_email INTO ls_email_temp
        WITH KEY pernr = ls_output-pernr.
      IF sy-subrc = 0.
        ls_output-usrid_long = ls_email_temp-usrid_long. " E-mail
      ENDIF.

      APPEND ls_output TO lt_output.
      CLEAR ls_output. " pulire per prox giro
    ENDIF.

  ENDLOOP.

  IF lt_output IS INITIAL.
    MESSAGE 'Nessun dato completo assemblato per l''output.' TYPE 'I'.
    EXIT.
  ENDIF.


* GENERAZIONE E SALVATAGGIO FILE CSV
  DATA: lt_csv_data TYPE STANDARD TABLE OF string,
        lv_csv_line TYPE string,
        lv_filename TYPE string,
        lv_pernr_txt TYPE string. "variabile di appoggio

  lv_csv_line = 'cognome;nome;username_hda;e-mail;cid'.
  APPEND lv_csv_line TO lt_csv_data.

  LOOP AT lt_output INTO ls_output.

    " gestione degli leading zeros con variabile di appoggio
    lv_pernr_txt = ls_output-pernr.
    shift lv_pernr_txt LEFT DELETING LEADING '0'.

    if lv_pernr_txt is initial.
      lv_pernr_txt = '0'.
    endif.

    CONCATENATE ls_output-nachn
                ls_output-vorna
                ls_output-bname
                ls_output-usrid_long
                "ls_output-pernr
                lv_pernr_txt
           INTO lv_csv_line
           SEPARATED BY ';'.

    APPEND lv_csv_line TO lt_csv_data.
  ENDLOOP.

  lv_filename = p_file.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename                = lv_filename "p_file
      filetype                = 'ASC'
    TABLES
      data_tab                = lt_csv_data
    EXCEPTIONS
      file_write_error        = 1
      no_batch                = 2
      gui_refuse_filetransfer = 3
      invalid_type            = 4
      no_authority            = 5
      unknown_error           = 6
      header_not_allowed      = 7
      separator_not_allowed   = 8
      filesize_not_allowed    = 9
      header_too_long         = 10
      dp_error_create         = 11
      dp_error_send           = 12
      dp_error_write          = 13
      unknown_dp_error        = 14
      access_denied           = 15
      dp_out_of_memory        = 16
      disk_full               = 17
      dp_timeout              = 18
      file_not_found          = 19
      dataprovider_exception  = 20
      control_flush_error     = 21
      OTHERS                  = 22.

  IF sy-subrc = 0.
    MESSAGE 'File CSV generato con successo nel percorso indicato.' TYPE 'S'.
  ELSE.
    MESSAGE 'Errore durante il salvataggio del file locale.' TYPE 'E'.
  ENDIF.