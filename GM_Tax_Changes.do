clear
set more off
set memory 900m
capture set matsize 900
capture set maxvar 12000

/************************************************************************************************************************************************************************************************
In order to replicate the analysis, run "GM_Tax_Changes.do". Before running this do file, set your working directory, copy and paste the root at the beginning of this do file. You must indicate your working directory in the order: 
-local path="XXXXXXX".

Then make this path your working directory. This creates a WORKING directory where all the files will be stored:
- cd `path'

********************************************************************/

local path="C:\data\GM_Tax_Changes"
cd `path'


** we create the log file so that we can create a readme file for github

log using GM_Tax_Changes.log, replace

**we call the sample selection and analysis files

do Dofiles/Sample_Creation_TCJA.do

do Dofiles/Analysis_DiD_TCJA.do

log close