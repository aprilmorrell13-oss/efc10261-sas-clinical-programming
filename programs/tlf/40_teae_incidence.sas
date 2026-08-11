/*************************************************************************
Program:        40_teae_incidence.sas
Study:          EFC10261
Purpose:        Produce TEAE incidence table

Source:
    ADAM.ADSL
    ADAM.ADAE

Output:
    OUTPUT/TABLES/teae_incidence.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Define safety population denominator and select TEAE records
-----------------------------------------------------------------------*/

proc sql noprint;
    select count(distinct USUBJID)
    into :saffn trimmed
    from adam.adsl
    where SAFFL = "Y";
quit;


data teae;
    set adam.adae(
        keep=
            USUBJID
            SAFFL
            TRTEMFL
            AEBODSYS
            AEDECOD
    );

    if SAFFL = "Y" and TRTEMFL = "Y";
run;


/*-----------------------------------------------------------------------
2. Create TEAE incidence summaries
-----------------------------------------------------------------------*/

/* Overall TEAE incidence */
proc sql;
    create table any_summary as
    select
        "ANY" as rowtype length=3,
        "" as AEBODSYS length=100,
        "Subjects with at least one TEAE" as label length=100,
        count(distinct USUBJID) as n,
        &saffn as denom,
        calculated n / calculated denom * 100 as pct
    from teae;
quit;


/* System Organ Class incidence */
proc sql;
    create table soc_summary as
    select
        "SOC" as rowtype length=3,
        AEBODSYS,
        AEBODSYS as label length=100,
        count(distinct USUBJID) as n,
        &saffn as denom,
        calculated n / calculated denom * 100 as pct
    from teae
    group by AEBODSYS;
quit;


/* Preferred Term incidence within System Organ Class */
proc sql;
    create table pt_summary as
    select
        "PT" as rowtype length=3,
        AEBODSYS,
        AEDECOD as label length=100,
        count(distinct USUBJID) as n,
        &saffn as denom,
        calculated n / calculated denom * 100 as pct
    from teae
    group by
        AEBODSYS,
        AEDECOD;
quit;


/*-----------------------------------------------------------------------
3. Derive SOC and PT display ordering
-----------------------------------------------------------------------*/

/* Order SOCs by descending subject incidence */
proc sort
    data=soc_summary
    out=soc_ordered;
    by descending n AEBODSYS;
run;


data soc_ordered;
    set soc_ordered;

    socord = _n_;
run;


/* Assign SOC ordering to Preferred Terms */
proc sql;
    create table pt_ordered as
    select
        a.*,
        b.socord
    from pt_summary as a

    left join soc_ordered as b
        on a.AEBODSYS = b.AEBODSYS;
quit;


/* Order PTs by descending subject incidence within SOC */
proc sort data=pt_ordered;
    by socord descending n label;
run;


data pt_ordered;
    set pt_ordered;

    by socord;

    if first.socord then
        ptord = 0;

    ptord + 1;
run;


/*-----------------------------------------------------------------------
4. Build final report-ready dataset
-----------------------------------------------------------------------*/

data final_report_raw;
    set
        any_summary
        soc_ordered
        pt_ordered;
run;


data final_report;
    set final_report_raw;

    length
        result        $20
        display_label $120
    ;


    /* Report ordering */
    if rowtype = "ANY" then do;
        majorord = 0;
        minorord = 0;
    end;

    else if rowtype = "SOC" then do;
        majorord = socord;
        minorord = 0;
    end;

    else if rowtype = "PT" then do;
        majorord = socord;
        minorord = ptord;
    end;


    /* Display variables */
    display_label = strip(label);

    result =
        strip(put(n, 3.))
        || " ("
        || strip(put(pct, 5.1))
        || ")";
run;


proc sort data=final_report;
    by majorord minorord;
run;


/*-----------------------------------------------------------------------
5. Generate TEAE incidence table
-----------------------------------------------------------------------*/

ods pdf
    file="&table_path/table_teae_incidence.pdf"
    style=journal;

title1 "EFC10261";
title2 "Treatment-Emergent Adverse Events";
title3 "Incidence by System Organ Class and Preferred Term";

footnote1
    "Percentages are based on the safety population (N=&saffn).";


proc report
    data=final_report
    nowd
    headline
    headskip;

    column
        majorord
        minorord
        rowtype
        display_label
        result;

    define majorord /
        order
        noprint;

    define minorord /
        order
        noprint;

    define rowtype /
        display
        noprint;

    define display_label /
        display
        "System Organ Class / Preferred Term"
        style(column)=[cellwidth=4.8in];

    define result /
        display
        "Placebo + Docetaxel (N=&saffn)"
        center
        style(column)=[cellwidth=1.4in];


    compute display_label;

        if rowtype = "PT" then
            call define(
                _col_,
                "style",
                "style=[leftmargin=0.20in]"
            );

        else if rowtype = "SOC" then
            call define(
                _col_,
                "style",
                "style=[font_weight=bold]"
            );

    endcomp;

run;


title;
footnote;

ods pdf close;
