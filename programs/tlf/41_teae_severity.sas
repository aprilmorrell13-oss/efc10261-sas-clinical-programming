/*************************************************************************
Program:        41_teae_severity.sas
Study:          EFC10261
Purpose:        Produce TEAE severity summary table

Source:
    ADAM.ADSL
    ADAM.ADAE

Output:
    OUTPUT/TABLES/table_teae_severity.pdf

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


data teae_sev;
    set adam.adae(
        keep=
            USUBJID
            SAFFL
            TRTEMFL
            AEBODSYS
            AEDECOD
            AETOXGR
    );

    if SAFFL = "Y" and TRTEMFL = "Y";

    grade_num = input(AETOXGR, best.);
run;


/*-----------------------------------------------------------------------
2. Derive maximum TEAE grade by analysis level
-----------------------------------------------------------------------*/

/* Maximum grade per subject overall */
proc summary data=teae_sev nway;
    class USUBJID;
    var grade_num;

    output out=any_max(drop=_TYPE_ _FREQ_)
        max=MAXGRADE;
run;


/* Maximum grade per subject within SOC */
proc summary data=teae_sev nway;
    class
        USUBJID
        AEBODSYS;

    var grade_num;

    output out=soc_max(drop=_TYPE_ _FREQ_)
        max=MAXGRADE;
run;


/* Maximum grade per subject within Preferred Term */
proc summary data=teae_sev nway;
    class
        USUBJID
        AEBODSYS
        AEDECOD;

    var grade_num;

    output out=pt_max(drop=_TYPE_ _FREQ_)
        max=MAXGRADE;
run;


/*-----------------------------------------------------------------------
3. Summarize subject counts by maximum grade
-----------------------------------------------------------------------*/

/* Overall */
proc sql;
    create table any_counts as
    select
        MAXGRADE,
        count(*) as n
    from any_max
    group by MAXGRADE;
quit;


/* System Organ Class */
proc sql;
    create table soc_counts as
    select
        AEBODSYS,
        MAXGRADE,
        count(*) as n
    from soc_max
    group by
        AEBODSYS,
        MAXGRADE;
quit;


/* Preferred Term */
proc sql;
    create table pt_counts as
    select
        AEBODSYS,
        AEDECOD,
        MAXGRADE,
        count(*) as n
    from pt_max
    group by
        AEBODSYS,
        AEDECOD,
        MAXGRADE;
quit;


/*-----------------------------------------------------------------------
4. Reshape severity counts to report structure
-----------------------------------------------------------------------*/

/* Overall */
proc sort data=any_counts;
    by MAXGRADE;
run;

proc transpose
    data=any_counts
    out=any_wide_raw(drop=_NAME_)
    prefix=grade;
    id MAXGRADE;
    var n;
run;


data any_wide;
    length
        rowtype $3
        AEBODSYS $100
        AEDECOD $120
        label $120
    ;

    set any_wide_raw;

    rowtype = "ANY";
    AEBODSYS = "";
    AEDECOD = "";
    label = "Subjects with at least one TEAE";
run;


/* System Organ Class */
proc sort data=soc_counts;
    by AEBODSYS MAXGRADE;
run;

proc transpose
    data=soc_counts
    out=soc_wide_raw(drop=_NAME_)
    prefix=grade;
    by AEBODSYS;
    id MAXGRADE;
    var n;
run;


data soc_wide;
    length
        rowtype $3
        AEDECOD $120
        label $120
    ;

    set soc_wide_raw;

    rowtype = "SOC";
    AEDECOD = "";
    label = AEBODSYS;
run;


/* Preferred Term */
proc sort data=pt_counts;
    by AEBODSYS AEDECOD MAXGRADE;
run;

proc transpose
    data=pt_counts
    out=pt_wide_raw(drop=_NAME_)
    prefix=grade;
    by AEBODSYS AEDECOD;
    id MAXGRADE;
    var n;
run;


data pt_wide;
    length
        rowtype $3
        label $120
    ;

    set pt_wide_raw;

    rowtype = "PT";
    label = AEDECOD;
run;


/*-----------------------------------------------------------------------
5. Prepare grade counts and calculate percentages
-----------------------------------------------------------------------*/

data any_wide;
    set any_wide;

    array grades[4] grade1-grade4;

    do i = 1 to 4;
        if missing(grades[i]) then
            grades[i] = 0;
    end;

    anygrade = sum(of grade1-grade4);

    array counts[5]
        anygrade
        grade1
        grade2
        grade3
        grade4;

    array pcts[5]
        pct_any
        pct1
        pct2
        pct3
        pct4;

    do i = 1 to 5;
        pcts[i] = counts[i] / &saffn * 100;
    end;

    drop i;
run;


data soc_wide;
    set soc_wide;

    array grades[4] grade1-grade4;

    do i = 1 to 4;
        if missing(grades[i]) then
            grades[i] = 0;
    end;

    anygrade = sum(of grade1-grade4);

    array counts[5]
        anygrade
        grade1
        grade2
        grade3
        grade4;

    array pcts[5]
        pct_any
        pct1
        pct2
        pct3
        pct4;

    do i = 1 to 5;
        pcts[i] = counts[i] / &saffn * 100;
    end;

    drop i;
run;


data pt_wide;
    set pt_wide;

    array grades[4] grade1-grade4;

    do i = 1 to 4;
        if missing(grades[i]) then
            grades[i] = 0;
    end;

    anygrade = sum(of grade1-grade4);

    array counts[5]
        anygrade
        grade1
        grade2
        grade3
        grade4;

    array pcts[5]
        pct_any
        pct1
        pct2
        pct3
        pct4;

    do i = 1 to 5;
        pcts[i] = counts[i] / &saffn * 100;
    end;

    drop i;
run;


/*-----------------------------------------------------------------------
6. Derive SOC and PT display ordering
-----------------------------------------------------------------------*/

/* Order SOCs by descending overall incidence */
proc sort
    data=soc_wide
    out=soc_ordered;
    by descending anygrade AEBODSYS;
run;


data soc_ordered;
    set soc_ordered;

    socord = _n_;
run;


/* Assign SOC order to Preferred Terms */
proc sql;
    create table pt_ordered as
    select
        a.*,
        b.socord
    from pt_wide as a

    left join soc_ordered as b
        on a.AEBODSYS = b.AEBODSYS;
quit;


/* Order PTs within SOC by descending incidence */
proc sort data=pt_ordered;
    by
        socord
        descending anygrade
        label;
run;


data pt_ordered;
    set pt_ordered;

    by socord;

    if first.socord then
        ptord = 0;

    ptord + 1;
run;


/*-----------------------------------------------------------------------
7. Build final report-ready dataset
-----------------------------------------------------------------------*/

data teae_sev_final;
    set
        any_wide
        soc_ordered
        pt_ordered;

    length
        result_any $20
        result1    $20
        result2    $20
        result3    $20
        result4    $20
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
    array counts[5]
        anygrade
        grade1
        grade2
        grade3
        grade4;

    array pcts[5]
        pct_any
        pct1
        pct2
        pct3
        pct4;

    array results[5] $20
        result_any
        result1
        result2
        result3
        result4;

    do i = 1 to 5;

        results[i] =
            strip(put(counts[i], 3.))
            || " ("
            || strip(put(pcts[i], 5.1))
            || ")";

    end;

    drop i;
run;


proc sort data=teae_sev_final;
    by majorord minorord;
run;


/*-----------------------------------------------------------------------
8. Generate TEAE severity table
-----------------------------------------------------------------------*/

options orientation=landscape;

ods pdf
    file="&table_path/table_teae_severity.pdf"
    style=journal;

title1 "EFC10261";
title2 "Treatment-Emergent Adverse Events";
title3 "Maximum Toxicity Grade by System Organ Class and Preferred Term";

footnote1
    "Values are n (%).";

footnote2
    "Each subject is counted once at the maximum observed toxicity grade within each category.";

footnote3
    "Percentages are based on the safety population (N=&saffn).";


proc report
    data=teae_sev_final
    nowd
    headline
    headskip;

    column
        majorord
        minorord
        rowtype
        label
        result_any
        result1
        result2
        result3
        result4;

    define majorord /
        order
        noprint;

    define minorord /
        order
        noprint;

    define rowtype /
        display
        noprint;

    define label /
        display
        "System Organ Class / Preferred Term"
        style(column)=[
            cellwidth=3.5in
        ];

    define result_any /
        display
        "Any Grade"
        center
        style(column)=[
            cellwidth=1.0in
            just=center
        ];

    define result1 /
        display
        "Grade 1"
        center
        style(column)=[
            cellwidth=0.9in
            just=center
        ];

    define result2 /
        display
        "Grade 2"
        center
        style(column)=[
            cellwidth=0.9in
            just=center
        ];

    define result3 /
        display
        "Grade 3"
        center
        style(column)=[
            cellwidth=0.9in
            just=center
        ];

    define result4 /
        display
        "Grade 4"
        center
        style(column)=[
            cellwidth=0.9in
            just=center
        ];


    compute label;

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

options orientation=portrait;