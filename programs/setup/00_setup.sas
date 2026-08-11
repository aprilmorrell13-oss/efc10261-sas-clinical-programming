/*************************************************************************
Program:        00_setup.sas
Study:          EFC10261
Purpose:        Initialize study libraries, output paths, and global
                SAS options used throughout the programming workflow.

Programmer:     April Morrell

Notes:
    Update ROOT as needed for the local SAS environment. All study
    libraries and output paths are derived from this location.
*************************************************************************/

/*-----------------------------------------------------------------------
  Study root directory
------------------------------------------------------------------------*/

%let root = /home/u64437635/efc10261-sas-clinical-programming;


/*-----------------------------------------------------------------------
  Study libraries
------------------------------------------------------------------------*/

libname sdtm   "&root/data/sdtm";
libname adam   "&root/data/adam";
libname qcadam "&root/data/qc";


/*-----------------------------------------------------------------------
  Output directories
------------------------------------------------------------------------*/

%let output_path  = &root/output;
%let table_path   = &output_path/tables;
%let listing_path = &output_path/listings;
%let figure_path  = &output_path/figures;
%let compare_path = &output_path/compare;


/*-----------------------------------------------------------------------
  Global SAS options
------------------------------------------------------------------------*/

options validvarname=upcase
        missing=' '
        nodate
        nonumber;


/*-----------------------------------------------------------------------
  Clear residual titles and footnotes
------------------------------------------------------------------------*/

title;
footnote;


/*-----------------------------------------------------------------------
  Environment confirmation
------------------------------------------------------------------------*/

%put NOTE: EFC10261 study environment initialized.;
%put NOTE: Study root = &root.;
