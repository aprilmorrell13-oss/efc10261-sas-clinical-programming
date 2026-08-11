/*************************************************************************
Program:        20_build_adae.sas
Study:          EFC10261
Purpose:        Create the adverse-events analysis dataset (ADAE)

Source:
    ADAM.ADSL
    SDTM.AE

Output:
    ADAM.ADAE
    OUTPUT/DATASETS/adae_summary.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Create adverse-events AE backbone
-----------------------------------------------------------------------*/

data ae_base;
    length USUBJID $18;

    set sdtm.ae;

    USUBJID = RUSUBJID;
run;


/*-----------------------------------------------------------------------
2. Prepare subject-level analysis variables
-----------------------------------------------------------------------*/

data adsl_base;
    set adam.adsl(
        keep=
            USUBJID
            AGE
            AGEU
            SEX
            RACE
            ARMCD
            ARM
            SAFFL
            TRTSDY
            TRTEDY
            TRTDUR
    );
run;


proc sort data=adsl_base;
    by USUBJID;
run;

proc sort data=ae_base;
    by USUBJID;
run;


/*-----------------------------------------------------------------------
3. Merge subject-level analysis variables onto AE records
-----------------------------------------------------------------------*/

data adam.adae;
    merge
        ae_base(in=in_ae)
        adsl_base;
    by USUBJID;

    if in_ae;
run;


/*-----------------------------------------------------------------------
4. Derive treatment-window analysis flags
-----------------------------------------------------------------------*/

data adam.adae;
    set adam.adae;

    length
        ONTRTFL   $1
        POSTTRTFL $1
        TRTEMFL   $1
    ;


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
    ONTRTFL   = "On-Treatment Flag"
    POSTTRTFL = "Post-Treatment Flag"
    TRTEMFL   = "Treatment-Emergent Flag";    
run;

/*-----------------------------------------------------------------------
5. Create ADAE dataset overview deliverables
-----------------------------------------------------------------------*/

/* Obtain dataset-level summary information */
proc sql noprint;
    select
        count(*),
        count(distinct USUBJID),
        count(distinct AEBODSYS),
        count(distinct AEDECOD),
        sum(TRTEMFL = "Y")
    into
        :adae_nobs trimmed,
        :adae_nsubj trimmed,
        :adae_nsoc trimmed,
        :adae_npt trimmed,
        :adae_nteae trimmed
    from adam.adae;

    select count(*)
    into :adae_nvars trimmed
    from dictionary.columns
    where libname = "ADAM"
      and memname = "ADAE";
quit;


/* Dataset overview */
data adae_overview;
    length
        Measure $45
        Value   $100
    ;

    Measure = "Dataset";
    Value   = "ADAE";
    output;

    Measure = "Purpose";
    Value   = "Adverse-events analysis dataset";
    output;

    Measure = "Structure";
    Value   = "One record per adverse event";
    output;

    Measure = "Source Data";
    Value   = "SDTM.AE + ADAM.ADSL";
    output;

    Measure = "Observations";
    Value   = strip(put(&adae_nobs, comma12.));
    output;

    Measure = "Unique Subjects";
    Value   = strip(put(&adae_nsubj, comma12.));
    output;

    Measure = "Variables";
    Value   = strip(put(&adae_nvars, comma12.));
    output;

    Measure = "System Organ Classes";
    Value   = strip(put(&adae_nsoc, comma12.));
    output;

    Measure = "Preferred Terms";
    Value   = strip(put(&adae_npt, comma12.));
    output;

    Measure = "Treatment-Emergent Records";
    Value   = strip(put(&adae_nteae, comma12.));
    output;

    Measure = "Source Program";
    Value   = "20_build_adae.sas";
    output;
run;


/* Key analysis variables and derivations */
data adae_derivations;
    length
        Variable    $10
        Source      $25
        Description $85
    ;

    Variable = "USUBJID";
    Source = "SDTM.AE";
    Description = "Unique subject identifier derived from RUSUBJID";
    output;

    Variable = "SAFFL";
    Source = "ADAM.ADSL";
    Description = "Safety population flag";
    output;

    Variable = "TRTSDY";
    Source = "ADAM.ADSL";
    Description = "Overall treatment start study day";
    output;

    Variable = "TRTEDY";
    Source = "ADAM.ADSL";
    Description = "Overall treatment end study day";
    output;

    Variable = "ONTRTFL";
    Source = "Derived";
    Description = "AE starts between treatment start and treatment end";
    output;

    Variable = "POSTTRTFL";
    Source = "Derived";
    Description = "AE starts after treatment through 30 days after treatment end";
    output;

    Variable = "TRTEMFL";
    Source = "Derived";
    Description = "AE starts from treatment start through 30 days after treatment end";
    output;
run;


/* Treatment-window flag summary */
proc sql;
    create table adae_flag_summary as

    select
        1 as Order,
        "ONTRTFL" as Variable length=10,
        "On-treatment" as Description length=40,
        sum(ONTRTFL = "Y") as Yes,
        sum(ONTRTFL = "N") as No,
        sum(missing(ONTRTFL)) as Missing,
        count(*) as Total
    from adam.adae

    union all

    select
        2,
        "POSTTRTFL",
        "Post-treatment through 30 days",
        sum(POSTTRTFL = "Y"),
        sum(POSTTRTFL = "N"),
        sum(missing(POSTTRTFL)),
        count(*)
    from adam.adae

    union all

    select
        3,
        "TRTEMFL",
        "Treatment-emergent",
        sum(TRTEMFL = "Y"),
        sum(TRTEMFL = "N"),
        sum(missing(TRTEMFL)),
        count(*)
    from adam.adae

    order by Order;
quit;


/* Capture variable metadata */
proc contents
    data=adam.adae
    out=adae_metadata_raw(
        keep=VARNUM NAME TYPE LENGTH LABEL
    )
    noprint;
run;

proc sort data=adae_metadata_raw;
    by VARNUM;
run;

data adae_metadata;
    set adae_metadata_raw;

    length Type_Display $9;

    if TYPE = 1 then
        Type_Display = "Numeric";
    else if TYPE = 2 then
        Type_Display = "Character";

    keep
        VARNUM
        NAME
        Type_Display
        LENGTH
        LABEL;
run;


/*-----------------------------------------------------------------------
6. Generate ADAE dataset overview
-----------------------------------------------------------------------*/

ods pdf
    file="&output_path/datasets/adae_summary.pdf"
    style=journal;

title1 "EFC10261 Analysis Data Model";
title2 "ADAE Dataset Overview";

ods text=
"ADAE is the adverse-events analysis dataset used for downstream safety
summaries. It retains source AE records and adds subject-level treatment,
population, and treatment-window analysis variables.";


/* Dataset overview */
proc report data=adae_overview nowd;
    column Measure Value;

    define Measure /
        display
        "Dataset Characteristic";

    define Value /
        display
        "Value";
run;


/* Key analysis variables */
ods pdf startpage=now;

title2 "Key Analysis Variables";

proc report data=adae_derivations nowd;
    column Variable Source Description;

    define Variable /
        display
        "Variable";

    define Source /
        display
        "Source";

    define Description /
        display
        "Description";
run;


/* Treatment-window flag summary */
ods pdf startpage=now;

title2 "Treatment Window Flag Summary";

proc report data=adae_flag_summary nowd;
    column Variable Description Yes No Missing Total;

    define Variable /
        display
        "Variable";

    define Description /
        display
        "Description";

    define Yes /
        display
        "Y, n";

    define No /
        display
        "N, n";

    define Missing /
        display
        "Missing, n";

    define Total /
        display
        "Total, n";
run;


/* Variable metadata */
ods pdf startpage=now;

title2 "Variable Metadata";

proc report data=adae_metadata nowd;
    column
        VARNUM
        NAME
        Type_Display
        LENGTH
        LABEL;

    define VARNUM /
        order
        "Order";

    define NAME /
        display
        "Variable";

    define Type_Display /
        display
        "Type";

    define LENGTH /
        display
        "Length";

    define LABEL /
        display
        "Label";
run;

title;
footnote;

ods pdf close;