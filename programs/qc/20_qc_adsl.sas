/*************************************************************************
Program:        20_qc_adsl.sas
Study:          EFC10261
Purpose:        Independently derive and validate ADSL

Source:
    SDTM.DM
    SDTM.EX
    SDTM.DS

Compare:
    ADAM.ADSL

Output:
    QCADAM.ADSL_QC
    OUTPUT/COMPARE/adsl_qc_compare.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Independently derive DM component
-----------------------------------------------------------------------*/

proc sql;
    create table qc_dm as
    select
        STUDYID,
        RUSUBJID as USUBJID length=18,
        AGE,
        AGEU,
        SEX,
        RACE,
        REGION,
        ARMCD,
        ARM,
        SAFETY as SAFFL length=1,
        RFSTDY,
        RFENDY
    from sdtm.dm;
quit;


/*-----------------------------------------------------------------------
2. Independently derive EX component
-----------------------------------------------------------------------*/

/* Summarize exposure by subject and treatment */
proc summary data=sdtm.ex nway;
    class RUSUBJID EXTRT;
    var EXSTDY EXENDY;

    output out=qc_ex_summary(drop=_TYPE_ _FREQ_)
        min(EXSTDY) = FIRSTDY
        max(EXENDY) = LASTDY;
run;


/* Reshape treatment-specific start and end days */
proc sort data=qc_ex_summary;
    by RUSUBJID;
run;

proc transpose
    data=qc_ex_summary
    out=qc_ex_start(drop=_NAME_)
    prefix=START_;
    by RUSUBJID;
    id EXTRT;
    var FIRSTDY;
run;

proc transpose
    data=qc_ex_summary
    out=qc_ex_end(drop=_NAME_)
    prefix=END_;
    by RUSUBJID;
    id EXTRT;
    var LASTDY;
run;


/* Derive subject-level exposure variables */
data qc_ex;
    merge
        qc_ex_start
        qc_ex_end;
    by RUSUBJID;

    DOCSDY = START_DOCETAXEL;
    DOCEDY = END_DOCETAXEL;
    PLBSDY = START_PLACEBO;
    PLBEDY = END_PLACEBO;

    if n(DOCSDY, DOCEDY) = 2 then
        DOCDUR = DOCEDY - DOCSDY + 1;

    if n(PLBSDY, PLBEDY) = 2 then
        PLBDUR = PLBEDY - PLBSDY + 1;

    TRTSDY = min(DOCSDY, PLBSDY);
    TRTEDY = max(DOCEDY, PLBEDY);

    if n(TRTSDY, TRTEDY) = 2 then
        TRTDUR = TRTEDY - TRTSDY + 1;

    keep
        RUSUBJID
        DOCSDY
        DOCEDY
        DOCDUR
        PLBSDY
        PLBEDY
        PLBDUR
        TRTSDY
        TRTEDY
        TRTDUR;
run;


/*-----------------------------------------------------------------------
3. Independently derive DS component
-----------------------------------------------------------------------*/

/* Confirm one relevant record per subject and disposition category */
proc sql;
    create table qc_ds_duplicates as
    select
        RUSUBJID,
        DSSCAT,
        count(*) as N_RECORDS
    from sdtm.ds
    where DSSCAT in (
        "END OF TREATMENT",
        "LAST CONTACT"
    )
    group by
        RUSUBJID,
        DSSCAT
    having count(*) > 1;
quit;


/* Derive end-of-treatment and last-contact components */
data qc_ds_eot(keep=RUSUBJID EOTRSN)
     qc_ds_last(keep=RUSUBJID LCONTDY LCONTST);

    length
        EOTRSN $40
        LCONTST $20
    ;

    set sdtm.ds;

    if DSSCAT = "END OF TREATMENT" then do;
        EOTRSN = DSDECOD;
        output qc_ds_eot;
    end;

    else if DSSCAT = "LAST CONTACT" then do;
        LCONTDY = DSSTDY;
        LCONTST = DSDECOD;
        output qc_ds_last;
    end;
run;


proc sort data=qc_ds_eot;
    by RUSUBJID;
run;

proc sort data=qc_ds_last;
    by RUSUBJID;
run;


/* Combine disposition components */
data qc_ds;
    merge
        qc_ds_eot
        qc_ds_last;
    by RUSUBJID;
run;


/*-----------------------------------------------------------------------
4. Build QC ADSL
-----------------------------------------------------------------------*/

proc sql;
    create table qcadam.adsl_qc as
    select
        a.STUDYID,
        a.USUBJID,
        a.AGE,
        a.AGEU,
        a.SEX,
        a.RACE,
        a.REGION,
        a.ARMCD,
        a.ARM,
        a.SAFFL,
        a.RFSTDY,
        a.RFENDY,

        b.DOCSDY,
        b.DOCEDY,
        b.DOCDUR,
        b.PLBSDY,
        b.PLBEDY,
        b.PLBDUR,
        b.TRTSDY,
        b.TRTEDY,
        b.TRTDUR,

        c.EOTRSN,
        c.LCONTDY,
        c.LCONTST

    from qc_dm as a

    left join qc_ex as b
        on a.USUBJID = b.RUSUBJID

    left join qc_ds as c
        on a.USUBJID = c.RUSUBJID

    order by a.USUBJID;
quit;


/*-----------------------------------------------------------------------
5. Apply labels to QC ADSL
-----------------------------------------------------------------------*/

data qcadam.adsl_qc;
    set qcadam.adsl_qc;

    label
        STUDYID = "Study Identifier"
        USUBJID = "Unique Subject Identifier"
        AGE     = "Age"
        AGEU    = "Age Units"
        SEX     = "Sex"
        RACE    = "Race"
        REGION  = "Geographic Region"
        ARMCD   = "Planned Arm Code"
        ARM     = "Description of Planned Arm"
        SAFFL   = "Safety Population Flag"
        RFSTDY  = "Reference Start Study Day"
        RFENDY  = "Reference End Study Day"
        DOCSDY  = "Docetaxel Start Study Day"
        DOCEDY  = "Docetaxel End Study Day"
        DOCDUR  = "Docetaxel Treatment Duration"
        PLBSDY  = "Placebo Start Study Day"
        PLBEDY  = "Placebo End Study Day"
        PLBDUR  = "Placebo Treatment Duration"
        TRTSDY  = "Overall Treatment Start Study Day"
        TRTEDY  = "Overall Treatment End Study Day"
        TRTDUR  = "Overall Treatment Duration"
        EOTRSN  = "End of Treatment Reason"
        LCONTDY = "Last Contact Study Day"
        LCONTST = "Last Contact Status"
    ;
run;


/*-----------------------------------------------------------------------
6. Validate QC dataset structure and derivations
-----------------------------------------------------------------------*/

proc sql;
    select
        count(*) as N_RECORDS,
        count(distinct USUBJID) as N_SUBJECTS,
        calculated N_RECORDS - calculated N_SUBJECTS
            as N_DUPLICATE_SUBJECTS,
        sum(missing(TRTSDY))
            as N_MISSING_EXPOSURE,
        sum(missing(EOTRSN))
            as N_MISSING_EOT_REASON,
        sum(missing(LCONTST))
            as N_MISSING_LAST_CONTACT_STATUS
    from qcadam.adsl_qc;
quit;


/* Validate treatment chronology and duration derivations */
proc sql;
    select
        sum(DOCEDY < DOCSDY)
            as N_DOC_END_BEFORE_START,
        sum(PLBEDY < PLBSDY)
            as N_PLB_END_BEFORE_START,
        sum(TRTEDY < TRTSDY)
            as N_TRT_END_BEFORE_START,
        sum(DOCDUR <= 0)
            as N_INVALID_DOC_DURATION,
        sum(PLBDUR <= 0)
            as N_INVALID_PLB_DURATION,
        sum(TRTDUR <= 0)
            as N_INVALID_TRT_DURATION
    from qcadam.adsl_qc;
quit;


/*-----------------------------------------------------------------------
7. Compare production and independently derived ADSL
-----------------------------------------------------------------------*/

proc sort data=adam.adsl;
    by USUBJID;
run;

proc sort data=qcadam.adsl_qc;
    by USUBJID;
run;


ods pdf
    file="&compare_path/adsl_qc_compare.pdf"
    style=journal;

title1 "EFC10261 ADSL Independent QC";
title2 "Production and Independent QC Comparison";

proc compare
    base=adam.adsl
    compare=qcadam.adsl_qc
    criterion=0.0000001
    listall;
    id USUBJID;
run;

title;
footnote;

ods pdf close;