/*************************************************************************
Program:        50_teae_soc_bar_chart.sas
Study:          EFC10261
Purpose:        Create TEAE incidence bar chart by System Organ Class

Source:
    ADAM.ADSL
    ADAM.ADAE

Output:
    OUTPUT/FIGURES/figure_teae_soc_incidence.png

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
    );

    if SAFFL = "Y" and TRTEMFL = "Y";
run;


/*-----------------------------------------------------------------------
2. Calculate TEAE subject incidence by System Organ Class
-----------------------------------------------------------------------*/

proc sql;
    create table soc_summary as
    select
        AEBODSYS,
        count(distinct USUBJID) as n,
        &saffn as denom,
        calculated n / calculated denom * 100
            as pct format=5.1
    from teae
    group by AEBODSYS;
quit;


/*-----------------------------------------------------------------------
3. Select top 10 System Organ Classes
-----------------------------------------------------------------------*/

proc sort
    data=soc_summary
    out=soc_ranked;
    by descending pct AEBODSYS;
run;


data soc_top10;
    set soc_ranked;

    if _N_ <= 10;
run;


/*-----------------------------------------------------------------------
4. Generate TEAE incidence figure
-----------------------------------------------------------------------*/

ods graphics /
    reset=index
    imagename="figure_teae_soc_incidence"
    imagefmt=png
    width=10in
    height=6.5in
    imagemap=off;

ods listing
    gpath="&figure_path";


title1 "EFC10261";
title2 "Treatment-Emergent Adverse Events";
title3 "Top 10 System Organ Classes by Subject Incidence";


proc sgplot data=soc_top10 noautolegend;

    hbar AEBODSYS /
        response=pct
        datalabel
        datalabelattrs=(size=9);

    yaxis
        display=(noticks nolabel)
        discreteorder=data;

    xaxis
        label="Subjects (%)"
        grid
        values=(0 to 60 by 10);

run;


title;
footnote;

ods listing close;
ods graphics / reset=all;