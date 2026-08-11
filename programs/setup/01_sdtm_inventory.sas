/*************************************************************************
Program:        01_sdtm_inventory.sas
Study:          EFC10261
Purpose:        Create dataset- and variable-level inventories for SDTM

Source:
    SDTM library metadata

Output:
    DOCUMENTATION/sdtm_inventory.pdf

Programmer:     April Morrell
*************************************************************************/

%include
    "/home/u64437635/efc10261-sas-clinical-programming/programs/setup/00_setup.sas";


/*-----------------------------------------------------------------------
1. Create dataset-level SDTM inventory
-----------------------------------------------------------------------*/

proc sql;
    create table sdtm_dataset_inventory as
    select
        memname as DOMAIN
            length=8
            label="Domain",

        memlabel as DESCRIPTION
            length=100
            label="Dataset Label",

        nobs as N_RECORDS
            label="Records",

        nvar as N_VARIABLES
            label="Variables"

    from dictionary.tables

    where libname = "SDTM"
      and memtype = "DATA"

    order by memname;
quit;


/*-----------------------------------------------------------------------
2. Create variable-level SDTM inventory
-----------------------------------------------------------------------*/

proc sql;
    create table sdtm_variable_inventory as
    select
        memname as DOMAIN
            length=8
            label="Domain",

        varnum as VARNUM
            label="Order",

        name as VARIABLE
            length=32
            label="Variable",

        case
            when type = "char" then "Character"
            when type = "num"  then "Numeric"
            else type
        end as TYPE_DISPLAY
            length=9
            label="Type",

        length as LENGTH
            label="Length",

        label as LABEL
            length=200
            label="Label"

    from dictionary.columns

    where libname = "SDTM"

    order by
        memname,
        varnum;
quit;


/*-----------------------------------------------------------------------
3. Create SDTM inventory overview
-----------------------------------------------------------------------*/

proc sql noprint;
    select
        count(*),
        sum(N_RECORDS),
        sum(N_VARIABLES)
    into
        :sdtm_ndomains trimmed,
        :sdtm_nrecords trimmed,
        :sdtm_nvariables trimmed
    from sdtm_dataset_inventory;
quit;


data sdtm_inventory_overview;
    length
        Measure $40
        Value   $60
    ;

    Measure = "Study";
    Value   = "EFC10261";
    output;

    Measure = "Source Library";
    Value   = "SDTM";
    output;

    Measure = "Number of Domains";
    Value   = strip(put(&sdtm_ndomains, comma12.));
    output;

    Measure = "Total Records Across Domains";
    Value   = strip(put(&sdtm_nrecords, comma12.));
    output;

    Measure = "Total Variables Across Domains";
    Value   = strip(put(&sdtm_nvariables, comma12.));
    output;

    Measure = "Source Program";
    Value   = "01_sdtm_inventory.sas";
    output;
run;


/*-----------------------------------------------------------------------
4. Generate SDTM inventory documentation
-----------------------------------------------------------------------*/

ods pdf
    file="&root/documentation/sdtm_inventory.pdf"
    style=journal;

title1 "EFC10261";
title2 "SDTM Source Data Inventory";


/* Study-level overview */
proc report data=sdtm_inventory_overview nowd;
    column
        Measure
        Value;

    define Measure /
        display
        "Inventory Characteristic"
        style(column)=[cellwidth=2.5in];

    define Value /
        display
        "Value"
        style(column)=[cellwidth=3.5in];
run;


/* Dataset-level inventory */
ods pdf startpage=now;

title2 "SDTM Dataset-Level Inventory";

proc report data=sdtm_dataset_inventory nowd;
    column
        DOMAIN
        DESCRIPTION
        N_RECORDS
        N_VARIABLES;

    define DOMAIN /
        display
        "Domain"
        style(column)=[cellwidth=0.7in];

    define DESCRIPTION /
        display
        "Dataset Label"
        style(column)=[cellwidth=3.2in];

    define N_RECORDS /
        display
        "Records"
        format=comma12.
        style(column)=[cellwidth=1.0in just=right];

    define N_VARIABLES /
        display
        "Variables"
        style(column)=[cellwidth=0.8in just=right];
run;


/* Variable-level inventory */
ods pdf startpage=now;

title2 "SDTM Variable-Level Inventory";

proc report data=sdtm_variable_inventory nowd;
    column
        DOMAIN
        VARNUM
        VARIABLE
        TYPE_DISPLAY
        LENGTH
        LABEL;

    define DOMAIN /
        order
        "Domain"
        style(column)=[cellwidth=0.6in];

    define VARNUM /
        display
        "Order"
        style(column)=[cellwidth=0.5in just=center];

    define VARIABLE /
        display
        "Variable"
        style(column)=[cellwidth=1.0in];

    define TYPE_DISPLAY /
        display
        "Type"
        style(column)=[cellwidth=0.8in];

    define LENGTH /
        display
        "Length"
        style(column)=[cellwidth=0.6in just=center];

    define LABEL /
        display
        "Label"
        style(column)=[cellwidth=3.0in];
run;


title;
footnote;

ods pdf close;