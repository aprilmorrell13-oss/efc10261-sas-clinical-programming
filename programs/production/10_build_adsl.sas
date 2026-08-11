/*************************************************************************
Program:        10_build_adsl.sas
Study:          EFC10261
Purpose:        Create the subject-level analysis dataset (ADSL)

Source:
    SDTM.DM
    SDTM.EX
    SDTM.DS

Output:
    ADAM.ADSL
    OUTPUT/DATASETS/adsl_summary.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Create subject-level DM backbone
-----------------------------------------------------------------------*/

data dm_base;
    length
        USUBJID $18
        SAFFL   $1
    ;

    set sdtm.dm(
        keep=
            STUDYID
            RUSUBJID
            AGE
            AGEU
            SEX
            RACE
            REGION
            ARMCD
            ARM
            SAFETY
            RFSTDY
            RFENDY
    );

    USUBJID = RUSUBJID;
    SAFFL   = SAFETY;

    drop RUSUBJID SAFETY;
run;


/*-----------------------------------------------------------------------
2. Derive subject-level treatment exposure variables
-----------------------------------------------------------------------*/

proc sql;
    create table ex_summary as
    select
        RUSUBJID,

        min(
            case
                when EXTRT = "DOCETAXEL" then EXSTDY
            end
        ) as DOCSDY
            label = "Docetaxel Start Study Day",

        max(
            case
                when EXTRT = "DOCETAXEL" then EXENDY
            end
        ) as DOCEDY
            label = "Docetaxel End Study Day",

        min(
            case
                when EXTRT = "PLACEBO" then EXSTDY
            end
        ) as PLBSDY
            label = "Placebo Start Study Day",

        max(
            case
                when EXTRT = "PLACEBO" then EXENDY
            end
        ) as PLBEDY
            label = "Placebo End Study Day"

    from sdtm.ex
    group by RUSUBJID;
quit;


data ex_summary;
    set ex_summary;

    if n(DOCSDY, DOCEDY) = 2 then
        DOCDUR = DOCEDY - DOCSDY + 1;

    if n(PLBSDY, PLBEDY) = 2 then
        PLBDUR = PLBEDY - PLBSDY + 1;

    TRTSDY = min(DOCSDY, PLBSDY);
    TRTEDY = max(DOCEDY, PLBEDY);

    if n(TRTSDY, TRTEDY) = 2 then
        TRTDUR = TRTEDY - TRTSDY + 1;

    label
        DOCDUR = "Docetaxel Treatment Duration"
        PLBDUR = "Placebo Treatment Duration"
        TRTSDY = "Overall Treatment Start Study Day"
        TRTEDY = "Overall Treatment End Study Day"
        TRTDUR = "Overall Treatment Duration"
    ;
run;


/*-----------------------------------------------------------------------
3. Derive subject-level disposition variables
-----------------------------------------------------------------------*/

proc sql;
    create table ds_summary as
    select
        RUSUBJID,

        max(
            case
                when DSSCAT = "END OF TREATMENT" then DSDECOD
            end
        ) as EOTRSN
            length = 40
            label = "End of Treatment Reason",

        max(
            case
                when DSSCAT = "LAST CONTACT" then DSSTDY
            end
        ) as LCONTDY
            label = "Last Contact Study Day",

        max(
            case
                when DSSCAT = "LAST CONTACT" then DSDECOD
            end
        ) as LCONTST
            length = 20
            label = "Last Contact Status"

    from sdtm.ds

    where DSSCAT in (
        "END OF TREATMENT",
        "LAST CONTACT"
    )

    group by RUSUBJID;
quit;


/*-----------------------------------------------------------------------
4. Create final ADSL
-----------------------------------------------------------------------*/

proc sort data=dm_base;
    by USUBJID;
run;

proc sort data=ex_summary;
    by RUSUBJID;
run;

proc sort data=ds_summary;
    by RUSUBJID;
run;


data adam.adsl;
    merge
        dm_base(in=in_dm)

        ex_summary(
            rename=(RUSUBJID = USUBJID)
        )

        ds_summary(
            rename=(RUSUBJID = USUBJID)
        )
    ;

    by USUBJID;

    if in_dm;

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
        EOTRSN  = "End of Treatment Reason"
        LCONTDY = "Last Contact Study Day"
        LCONTST = "Last Contact Status"
    ;
run;

/*-----------------------------------------------------------------------
5. Create ADSL dataset overview deliverables
-----------------------------------------------------------------------*/

/* Obtain dataset-level summary information */
proc sql noprint;
    select
        count(*),
        count(distinct USUBJID),
        sum(SAFFL = "Y")
    into
        :adsl_nobs trimmed,
        :adsl_nsubj trimmed,
        :adsl_nsafety trimmed
    from adam.adsl;

    select count(*)
    into :adsl_nvars trimmed
    from dictionary.columns
    where libname = "ADAM"
      and memname = "ADSL";
quit;


/* Dataset overview */
data adsl_overview;
    length
        Measure $45
        Value   $100
    ;

    Measure = "Dataset";
    Value   = "ADSL";
    output;

    Measure = "Purpose";
    Value   = "Subject-level analysis dataset";
    output;

    Measure = "Structure";
    Value   = "One record per subject";
    output;

    Measure = "Source Domains";
    Value   = "SDTM.DM, SDTM.EX, SDTM.DS";
    output;

    Measure = "Observations";
    Value   = strip(put(&adsl_nobs, comma12.));
    output;

    Measure = "Unique Subjects";
    Value   = strip(put(&adsl_nsubj, comma12.));
    output;

    Measure = "Variables";
    Value   = strip(put(&adsl_nvars, comma12.));
    output;

    Measure = "Safety Population";
    Value   = catx(strip(put(&adsl_nsafety, comma12.)), " subjects");
    output;

    Measure = "Created By";
    Value   = "10_build_adsl.sas";
    output;
run;


/* Key derived variables */
data adsl_derivations;
    length
        Variable $10
        Source $20
        Description $80
    ;

    Variable="SAFFL";
    Source="DM";
    Description="Safety population flag";
    output;

    Variable="DOCSDY";
    Source="EX";
    Description="First docetaxel exposure day";
    output;

    Variable="DOCEDY";
    Source="EX";
    Description="Last docetaxel exposure day";
    output;

    Variable="DOCDUR";
    Source="Derived";
    Description="Docetaxel treatment duration";
    output;

    Variable="PLBSDY";
    Source="EX";
    Description="First placebo exposure day";
    output;

    Variable="PLBEDY";
    Source="EX";
    Description="Last placebo exposure day";
    output;

    Variable="PLBDUR";
    Source="Derived";
    Description="Placebo treatment duration";
    output;

    Variable="TRTSDY";
    Source="Derived";
    Description="Overall treatment start day";
    output;

    Variable="TRTEDY";
    Source="Derived";
    Description="Overall treatment end day";
    output;

    Variable="TRTDUR";
    Source="Derived";
    Description="Overall treatment duration";
    output;

    Variable="EOTRSN";
    Source="DS";
    Description="End of treatment reason";
    output;

    Variable="LCONTDY";
    Source="DS";
    Description="Last contact study day";
    output;

    Variable="LCONTST";
    Source="DS";
    Description="Last contact status";
    output;
run;


/* Metadata */
proc contents
    data=adam.adsl
    out=adsl_metadata_raw(
        keep=VARNUM NAME TYPE LENGTH LABEL
    )
    noprint;
run;

proc sort data=adsl_metadata_raw;
    by VARNUM;
run;

data adsl_metadata;
    set adsl_metadata_raw;

    length Type_Display $9;

    if TYPE=1 then
        Type_Display="Numeric";
    else
        Type_Display="Character";

    keep
        VARNUM
        NAME
        Type_Display
        LENGTH
        LABEL;
run;


/* Completeness of key derived variables */
proc sql;
    create table adsl_completeness as

    select
        1 as Order,
        "TRTSDY" as Variable length=8,
        "Overall Treatment Start Study Day" as Description length=45,
        sum(missing(TRTSDY)) as Missing
    from adam.adsl

    union all

    select
        2,
        "TRTEDY",
        "Overall Treatment End Study Day",
        sum(missing(TRTEDY))
    from adam.adsl

    union all

    select
        3,
        "EOTRSN",
        "End of Treatment Reason",
        sum(missing(EOTRSN))
    from adam.adsl

    union all

    select
        4,
        "LCONTDY",
        "Last Contact Study Day",
        sum(missing(LCONTDY))
    from adam.adsl

    union all

    select
        5,
        "LCONTST",
        "Last Contact Status",
        sum(missing(LCONTST))
    from adam.adsl

    order by Order;
quit;

/*-----------------------------------------------------------------------
6. Generate ADSL dataset overview
-----------------------------------------------------------------------*/

ods pdf
    file="&output_path/datasets/adsl_summary.pdf"
    style=journal;

title1 "EFC10261 Analysis Data Model";
title2 "ADSL Dataset Overview";

ods text=
"ADSL is the subject-level analysis dataset used as the analysis backbone
for downstream safety analyses. It integrates demographic, treatment
exposure, and disposition information into one record per subject.";


/* Overview */

proc report data=adsl_overview nowd;
    column Measure Value;

    define Measure / display "Dataset Characteristic";
    define Value   / display "Value";
run;


/* Key derivations */

ods pdf startpage=now;

title2 "Key Derived Variables";

proc report data=adsl_derivations nowd;
    column Variable Source Description;

    define Variable / display;
    define Source / display;
    define Description / display;
run;


/* Completeness */

ods pdf startpage=now;

title2 "Derived Variable Completeness";

proc report data=adsl_completeness nowd;
    column Variable Description Missing;

    define Variable / display;
    define Description / display;
    define Missing / display "Missing, n";
run;


/* Metadata */

ods pdf startpage=now;

title2 "Variable Metadata";

proc report data=adsl_metadata nowd;
    column
        VARNUM
        NAME
        Type_Display
        LENGTH
        LABEL;

    define VARNUM / order "Order";
    define NAME / display "Variable";
    define Type_Display / display "Type";
    define LENGTH / display "Length";
    define LABEL / display "Label";
run;

title;
footnote;

ods pdf close;