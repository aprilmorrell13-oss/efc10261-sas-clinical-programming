/*************************************************************************
Program:        51_teae_severity_bar_chart.sas
Study:          EFC10261
Purpose:        Create TEAE toxicity grade distribution bar chart

Source:
    ADAM.ADAE

Output:
    OUTPUT/FIGURES/figure_teae_severity_distribution.png

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Select TEAE records with observed toxicity grade
-----------------------------------------------------------------------*/

data teae_severity;
    set adam.adae(
        keep=
            SAFFL
            TRTEMFL
            AETOXGR
    );

    if SAFFL = "Y"
       and TRTEMFL = "Y"
       and not missing(AETOXGR);

    grade_num = input(AETOXGR, best.);

    length grade_label $10;
    grade_label = catx(" ", "Grade", strip(AETOXGR));

    keep
        grade_num
        grade_label;
run;


/*-----------------------------------------------------------------------
2. Calculate TEAE event distribution by toxicity grade
-----------------------------------------------------------------------*/

proc sql noprint;
    select count(*)
    into :teae_grade_n trimmed
    from teae_severity;
quit;


proc sql;
    create table severity_summary as
    select
        grade_num,
        grade_label,
        count(*) as n_events,
        calculated n_events / &teae_grade_n * 100
            as pct format=5.1
    from teae_severity
    group by
        grade_num,
        grade_label
    order by grade_num;
quit;


/*-----------------------------------------------------------------------
3. Generate TEAE toxicity grade distribution figure
-----------------------------------------------------------------------*/

ods graphics /
    reset=index
    imagename="figure_teae_severity_distribution"
    imagefmt=png
    width=8in
    height=6in
    imagemap=off;

ods listing
    gpath="&figure_path";


title1 "EFC10261";
title2 "Treatment-Emergent Adverse Events";
title3 "Distribution of TEAE Events by Toxicity Grade";

footnote1
    "Percentages are based on TEAE records with nonmissing toxicity grade (N=&teae_grade_n).";


proc sgplot data=severity_summary noautolegend;

    vbar grade_label /
        response=pct
        datalabel
        datalabelattrs=(size=9);

    xaxis
        label="Toxicity Grade"
        discreteorder=data;

    yaxis
        label="TEAE Events (%)"
        grid;

run;


title;
footnote;

ods listing close;
ods graphics / reset=all;