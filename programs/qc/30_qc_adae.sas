/*************************************************************************
Program:        30_qc_adae.sas
Study:          EFC10261
Purpose:        Independently derive and validate ADAE

Source:
    SDTM.AE
    ADAM.ADSL

Compare:
    ADAM.ADAE

Output:
    QCADAM.ADAE_QC
    OUTPUT/COMPARE/adae_qc_compare.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Independently derive ADAE source structure
-----------------------------------------------------------------------*/

proc sql;
    create table qcadam.adae_qc as
    select
        ae.*,
        adsl.AGE,
        adsl.AGEU,
        adsl.SEX,
        adsl.RACE,
        adsl.ARMCD,
        adsl.ARM,
        adsl.SAFFL,
        adsl.TRTSDY,
        adsl.TRTEDY,
        adsl.TRTDUR
    from sdtm.ae as ae

    left join adam.adsl as adsl
        on ae.RUSUBJID = adsl.USUBJID;
quit;


/*-----------------------------------------------------------------------
2. Independently derive ADAE analysis variables
-----------------------------------------------------------------------*/

data qcadam.adae_qc;
    set qcadam.adae_qc;

    length
        USUBJID   $18
        ONTRTFL   $1
        POSTTRTFL $1
        TRTEMFL   $1
    ;

    USUBJID = RUSUBJID;


    /* On-treatment flag */
    if missing(AESTDY) or
       missing(TRTSDY) or
       missing(TRTEDY) then
        ONTRTFL = "";

    else if TRTSDY <= AESTDY <= TRTEDY then
        ONTRTFL = "Y";

    else
        ONTRTFL = "N";


    /* Post-treatment flag: through 30 days after treatment */
    if missing(AESTDY) or
       missing(TRTEDY) then
        POSTTRTFL = "";

    else if TRTEDY < AESTDY <= TRTEDY + 30 then
        POSTTRTFL = "Y";

    else
        POSTTRTFL = "N";


    /* Treatment-emergent flag */
    if missing(AESTDY) or
       missing(TRTSDY) or
       missing(TRTEDY) then
        TRTEMFL = "";

    else if TRTSDY <= AESTDY <= TRTEDY + 30 then
        TRTEMFL = "Y";

    else
        TRTEMFL = "N";


    label
    	USUBJID = "Unique Subject Identifier"
        ONTRTFL   = "On-Treatment Flag"
        POSTTRTFL = "Post-Treatment Flag"
        TRTEMFL   = "Treatment-Emergent Flag"
    ;
run;


/*-----------------------------------------------------------------------
3. Validate QC dataset structure and source linkage
-----------------------------------------------------------------------*/

proc sql;
    select
        count(*) as N_RECORDS,
        count(distinct USUBJID) as N_SUBJECTS,
        sum(missing(SAFFL)) as N_MISSING_ADSL_LINK,
        sum(missing(TRTSDY)) as N_MISSING_TRTSDY,
        sum(missing(TRTEDY)) as N_MISSING_TRTEDY
    from qcadam.adae_qc;
quit;


/*-----------------------------------------------------------------------
4. Validate treatment-window flags
-----------------------------------------------------------------------*/

proc sql;
    select
        count(*) as N_RECORDS,

        sum(ONTRTFL = "Y") as N_ONTRT,
        sum(ONTRTFL = "N") as N_NOT_ONTRT,
        sum(missing(ONTRTFL)) as N_ONTRT_MISSING,

        sum(POSTTRTFL = "Y") as N_POSTTRT,
        sum(POSTTRTFL = "N") as N_NOT_POSTTRT,
        sum(missing(POSTTRTFL)) as N_POSTTRT_MISSING,

        sum(TRTEMFL = "Y") as N_TRTEM,
        sum(TRTEMFL = "N") as N_NON_TRTEM,
        sum(missing(TRTEMFL)) as N_TRTEM_MISSING

    from qcadam.adae_qc;
quit;


/* Confirm logical consistency among treatment-window flags */
proc sql;
    select
        sum(
            ONTRTFL = "Y" and TRTEMFL ne "Y"
        ) as N_ONTRT_NOT_TRTEM,

        sum(
            POSTTRTFL = "Y" and TRTEMFL ne "Y"
        ) as N_POSTTRT_NOT_TRTEM,

        sum(
            ONTRTFL = "Y" and POSTTRTFL = "Y"
        ) as N_ONTRT_AND_POSTTRT

    from qcadam.adae_qc;
quit;


/*-----------------------------------------------------------------------
5. Compare production and independently derived ADAE
-----------------------------------------------------------------------*/

proc sort data=adam.adae;
    by USUBJID AESEQ;
run;

proc sort data=qcadam.adae_qc;
    by USUBJID AESEQ;
run;


ods pdf
    file="&compare_path/adae_qc_compare.pdf"
    style=journal;

title1 "EFC10261 ADAE Independent QC";
title2 "Production and Independent QC Comparison";

proc compare
    base=adam.adae
    compare=qcadam.adae_qc
    criterion=0.0000001
    listall;
    id USUBJID AESEQ;
run;

title;
footnote;

ods pdf close;