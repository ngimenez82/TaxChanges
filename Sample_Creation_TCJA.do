/*******************************************************************************
*
*  Sample_Creation_TCJA.do
*
*  PURPOSE: Build analysis samples for the paper
*    "Causal Effects of Financial Complexity Shocks on Time Use and
*     Emotional Well-Being: Evidence from Tax Policy Changes (TCJA 2017)"
*
*  INPUTS:
*    - Data/ATUS_Clean.dta               (from existing Sample_Creation_Financial.do)
*    - Data/TCJA_State_Treatment.dta     (derived from IRS SOI Historic Table 2;
*                                         see TCJA_State_Data_DiD.xlsx, Sheet 1)
*
*  OUTPUTS:
*    - Data/TCJA_Financial_Time.dta      (individual-level time-use sample)
*    - Data/TCJA_Financial_WellBeing.dta (episode-level well-being sample)
*
*  SAMPLE PERIOD: 2013-2023 (ATUS waves spanning pre/post TCJA, -5/+5 window)
*  IDENTIFICATION: Difference-in-Differences
*    - Treatment: households with income >= $50k (famincome >= 12)
*                 plausibly switched from itemizing to standard deduction
*    - Control  : households with income < $35k (famincome <= 9)
*                 rarely itemized in either period
*    - Post      : year >= 2018 (TCJA effective Jan 1, 2018)
*    - Event time: t = 0  -> 2018 (entry into force)
*                  t = -1 -> 2017 (base / omitted year)
*                  Window: -5/+5
*
*  NOTES:
*    - Parallel trends tested using pre-reform ATUS waves (2013-2017)
*    - ATUS WBM available only in 2010, 2012, 2013, 2021 - use 2013 as
*      pre-period and 2021 as post-period for well-being analysis
*    - Homeownership not directly in ATUS; proxied by income + marriage
*      (see treatment_proxy variable below)
*
*  REVISION HISTORY (response to JEBO reviewer comments, Aug 2026):
*    - NEW: tax_act / tax_time / tax  - narrow "tax and insurance" outcome,
*      subset of `financial`, per Reviewer #2's request for a higher-powered,
*      more directly-affected outcome (see PART VII, Analysis do-file).
*    - NEW: month / tax_season - interview-month based tax-filing-season flag
*      and triple-diff support variables (treat_x_season, post_x_season,
*      did_x_season), per Reviewer #1 pt.3 and Reviewer #2 "tax season"
*      comments. REQUIRES an interview-month variable in ATUS_Clean.dta -
*      see the guarded block below; edit it if your extract uses a
*      different variable name.
*    - NEW: in_did_sample flag + diagnostic tabulations, to resolve the
*      Reviewer #2 minor comment about the "transition zone" ($35-50k)
*      being described as excluded (p.9) but apparently included in some
*      Table 3 columns. This script does NOT silently redefine the analysis
*      sample - it surfaces the discrepancy so you can fix whichever side
*      (text or code) is wrong, since I cannot verify the actual N's without
*      running your data.
*    - NEW: state-level itemization-decline diagnostic (delta_1718 by
*      group), used in the Analysis do-file's magnitude/plausibility check
*      (Reviewer #1 pt.4).
*
*  AUTHOR: [Your name]
*  LAST UPDATED: 2026
*
*******************************************************************************/

clear
set more off

********************************************************************************
** STEP 1: CREATE STATE-LEVEL TCJA TREATMENT INTENSITY FILE
** (Run once; skip if Data/TCJA_State_Treatment.dta already exists)
********************************************************************************

*  Enter the state-level itemization rates from the Excel file
*  (TCJA_State_Data_DiD.xlsx, Sheet 1).
*  pre_itemize_rate = average itemization rate 2015-2017 (treatment intensity)
*  post_itemize_rate = average itemization rate 2018-2022

*  *** IMPORT FROM EXCEL ***
capture confirm file "Data/TCJA_State_Treatment.dta"
if _rc != 0 {

    import excel using "Data/TCJA_State_Data_DiD.xlsx", ///
        sheet("1_State_TCJA_Data") cellrange(A4:S54) clear

    *--- rename columns imported from Excel to Stata-friendly names ---
    rename (A B C D E F G H I J K L M N O P Q R) ///
           (state_name state_abbr statefip ///
            item2015 item2016 item2017 item2018 item2019 item2020 item2021 item2022 ///
            delta_1718 treat_intensity ///
            homeown_rate med_hh_income top_state_tax med_home_val no_income_tax)

    *--- Force ALL numeric columns to numeric (Excel often imports them as strings) ---
    destring statefip item2015 item2016 item2017 item2018 item2019 ///
             item2020 item2021 item2022 delta_1718 treat_intensity ///
             homeown_rate med_hh_income top_state_tax med_home_val no_income_tax, ///
             replace ignore(",%$ ")

    *--- drop national row & any blank trailing rows ---
    drop if missing(statefip)
    drop if statefip == 0

    *--- Recompute treat_intensity and delta_1718 in Stata ---
    *   The Excel columns L (delta_1718) and M (treat_intensity) are unreliable
    *   (often empty or 0). Derive them directly from the item20XX series.
    drop treat_intensity delta_1718
    generate treat_intensity = (item2015 + item2016 + item2017) / 3
    generate delta_1718      = item2018 - item2017

    *--- Sanity check: treat_intensity must vary across states ---
    qui sum treat_intensity
    if r(sd) == 0 | r(sd) == . {
        di as error "ERROR: treat_intensity has no variation across states."
        di as error "Check item2015-item2017 in the Excel file (columns D-F)."
        di as error "Aborting STEP 1 - the saved .dta would be unusable."
        exit 459
    }
    di as text "OK: treat_intensity computed from item2015-2017, " ///
       "varies across `=_N' states " ///
       "(min = `: di %4.3f r(min)', max = `: di %4.3f r(max)', " ///
       "sd = `: di %4.3f r(sd)')."

    *--- label ---
    label variable treat_intensity ///
        "State avg itemization rate 2015-17 (DiD treatment intensity)"
    label variable item2017 "Share returns itemized, 2017 (pre-TCJA)"
    label variable delta_1718 "pp change in itemization 2017-2018 (TCJA shock)"
    label variable homeown_rate "Homeownership rate 2016 (Census ACS)"
    label variable top_state_tax "Top marginal state income tax rate 2017"
    label variable no_income_tax "= 1 if state has no personal income tax"

    *--- quintiles of treatment intensity (for heterogeneity) ---
    xtile treat_quintile = treat_intensity, nq(5)
    label variable treat_quintile "Quintile of pre-TCJA itemization intensity"

    save "Data/TCJA_State_Treatment.dta", replace
    di "State treatment file saved with `=_N' states."
}


********************************************************************************
** STEP 2: BUILD THE TIME-USE SAMPLE (equivalent to Financial_Time_in_Activities)
********************************************************************************

clear
use "Data/ATUS_Clean.dta", clear

*--- Restrict to 2013-2023 (extended for -5/+5 event-study window) ---
keep if year >= 2013 & year <= 2023

*--- Employment filter (same as original paper) ---
drop if empstat == 2        // absent from work
rename clwkr class_of_worker

generate government_worker   = inlist(class_of_worker, 1, 2, 3)
generate private_worker      = inlist(class_of_worker, 4, 5)
generate self_employed_worker = inlist(class_of_worker, 6, 7)

foreach v of varlist government_worker private_worker self_employed_worker {
    replace `v' = 0 if `v' == .
}

*--- Activity classifications (identical to original code) ---
generate financial_act = 1 if inlist(activity, ///
    20901, 20902, 80201, 80202, 80203, 80299, 100103, 180802)

*--- NEW: narrow "tax and insurance" activity subset of financial_act ---
*   Reviewer #2: "It would seem obvious to examine sensitivity to a narrower
*   time use outcome: time spent on tax planning specifically." Codes
*   20902 (tax preparation/filing) and 100103 (using financial services,
*   incl. insurance claims) are the subset of financial_act's codes that
*   plausibly respond to the standard-deduction change, as opposed to
*   day-to-day banking/investment management which should not.
generate tax_act = 1 if inlist(activity, 20902, 100103)

generate personal_care_act = 1 if inlist(activity, ///
    10101,10102,10199,10201,10299,10301,10399,10401,10499,10501,10599,19999, ///
    80401,80402,80403,80499,80501,80502,80599,110101,110201,110299,119999, ///
    180101,180199,180804,180805,180899,181101,181199)

generate housework_act = 1 if inlist(activity, ///
    20101,20102,20103,20104,20199,20201,20202,20203,20299,20301,20302,20303,20399, ///
    20401,20402,20499,20501,20502,20599,20601,20602,20603,20699,20701,20799,20801,20899, ///
    20903,20904,20905,20999,29999,40501,40502,40503,40504,40505,40506,40507,40508,40599,49999, ///
    70101,70102,70103,70104,70105,70199,70201,70299,70301,70399,79999,80301,80302,80399, ///
    80601,80602,80699,80701,80702,80799,80801,89999,90101,90102,90103,90104,90199,90201,90202, ///
    90299,90301,90302,90399,90401,90402,90499,90501,90502,90599,99999,100101,100102,100199, ///
    100201,100299,100303,100304,100399,100401,100499,109999,180201,180202,180203,180204,180205, ///
    180206,180207,180208,180209,180299,180701,180702,180703,180704,180705,180799,180801,180803, ///
    180806,180807,180901,180902,180903,180904,180905,180999,181001,181002,181099)

generate childcare_act = 1 if inlist(activity, ///
    30101,30102,30103,30104,30105,30106,30107,30108,30109,30110,30111,30112,30199, ///
    30201,30202,30203,30204,30299,30301,30302,30303,30399,30401,30402,30403,30404,30405,30499, ///
    40101,40102,40103,40104,40105,40106,40107,40108,40109,40110,40111,40112,40199, ///
    40201,40202,40203,40204,40299,40301,40302,40303,40399,80101,80102,80199, ///
    180301,180302,180303,180304,180401,180402,180403,180404)

generate adult_care_act = 1 if inlist(activity, ///
    30501,30502,30503,30504,30599,39999,40401,40402,40403,40404,40405,40499, ///
    180305,180306,180307,180399,180405,180406,180407,180499)

generate market_work_act = 1 if inlist(activity, ///
    50101,50102,50103,50104,50199,50201,50202,50203,50204,50205,50299, ///
    50301,50302,50303,50304,50305,50399,50401,50403,50404,50405,50499,59999, ///
    180501,180502,180503,180504,180599)

generate study_act = 1 if inlist(activity, ///
    60101,60102,60103,60104,60199,60201,60202,60203,60204,60299,60301,60302,60303,60399, ///
    60401,60402,60403,60499,69999,180601,180602,180603,180604,180605,180699)

generate leisure_act = 1 if inlist(activity, ///
    120101,120199,120201,120202,120299,120301,120302,120303,120304,120305,120306,120307, ///
    120308,120309,120310,120311,120312,120313,120399,120401,120402,120403,120404,120405,120499, ///
    120501,120502,120503,120504,120599,129999,130101,130102,130103,130104,130105,130106,130107, ///
    130108,130109,130110,130111,130112,130113,130114,130115,130116,130117,130118,130119,130120, ///
    130121,130122,130123,130124,130125,130126,130127,130128,130129,130130,130131,130132,130133, ///
    130134,130135,130136,130199,130201,130202,130203,130204,130205,130206,130207,130209,130210, ///
    130211,130212,130213,130214,130215,130216,130217,130218,130219,130220,130221,130222,130223, ///
    130224,130225,130226,130227,130229,130230,130231,130232,130299,130301,130302,130399,130401, ///
    130402,139999,140101,140102,140103,140104,140105,149999,150101,150102,150103,150104,150105, ///
    150106,150199,150201,150202,150203,150204,150299,150301,150302,150399,150401,150402,150499, ///
    150501,150599,150601,150602,150699,150701,150799,150801,150899,159999,160101,160102,160103, ///
    160104,160105,160106,160107,160108,160199,160201,160299,169999,181201,181202,181203,181204, ///
    181205,181206,181299,181301,181302,181399,181401,181499,181501,181599,181601,181699, ///
    181801,181899,189999)

foreach v of varlist personal_care_act housework_act financial_act tax_act childcare_act ///
                       adult_care_act market_work_act study_act leisure_act {
    replace `v' = 0 if `v' == .
}

*--- Aggregate time per activity category ---
foreach act in personal_care housework financial childcare adult_care ///
               market_work study leisure {
    generate `act'_time = duration if `act'_act == 1
    replace  `act'_time = 0 if `act'_time == .
}

sort caseid
foreach act in personal_care housework financial childcare adult_care ///
               market_work study leisure {
    by caseid: egen `act' = sum(`act'_time)
}

*--- NEW: aggregate narrow tax/insurance time (subset of `financial`) ---
*   Kept as a SEPARATE variable, not added into total_time, to avoid
*   double-counting (its minutes are already inside `financial`).
generate tax_time = duration if tax_act == 1
replace  tax_time = 0 if tax_time == .
sort caseid
by caseid: egen tax = sum(tax_time)
label variable tax "Daily minutes: tax prep/filing + insurance claims (narrow outcome; subset of financial)"

generate total_time = personal_care + housework + financial + childcare + ///
                      adult_care + market_work + study + leisure

*--- Wages ---
replace earnweek = . if earnweek == 0 | earnweek == 99999.99
replace hourwage = . if hourwage == 0 | hourwage == 999.99
replace otpay    = 0 if otpay >= 3000
gen wage = hourwage if hourwage != .
replace wage = earnweek / uhrsworkt if wage == . & earnweek != .
replace wage = wage + otpay / uhrsworkt if wage != .
replace wage = . if uhrsworkt == 9995 & hourwage > 100

*--- Keep one record per person-day ---
keep if actline == 1

*--- Sample filters ---
drop if famincome > 16
replace ageychild = 0 if ageychild > 17
generate age_2 = (age * age) / 100
drop if total_time < 1440      // must have complete diary day

*--- Wage weight ---
replace wt06 = wt20 if wt06 == .


********************************************************************************
** STEP 3: CONSTRUCT DiD TREATMENT VARIABLES
********************************************************************************

*--- Time variables ---
generate post_tcja = (year >= 2018)
label variable post_tcja "= 1 if year >= 2018 (TCJA effective Jan 1, 2018)"

*--- NEW: interview month + tax filing season indicator ---
*   Reviewer #1 (pt.3) and Reviewer #2 both suggest exploiting the fact that
*   the standard-deduction change should only plausibly affect time use
*   during the filing season (~mid-Jan to mid-Apr), not year-round. This
*   requires an interview-month variable in ATUS_Clean.dta.
*   IMPORTANT: verify the correct variable name for YOUR extract. IPUMS
*   ATUS-X extracts typically call it MONTH. The block below tries a couple
*   of common alternatives and stops with an informative error rather than
*   silently mis-defining tax_season if none is found - do not remove the
*   "exit" without first confirming the correct variable name.
capture confirm variable month
if _rc != 0 {
    capture confirm variable tumonth
    if _rc == 0 {
        rename tumonth month
    }
    else {
        capture confirm variable intmonth
        if _rc == 0 {
            rename intmonth month
        }
        else {
            di as error "ERROR: no interview-month variable found in ATUS_Clean.dta"
            di as error "(tried: month, tumonth, intmonth)."
            di as error "Re-extract from IPUMS ATUS-X including MONTH, or edit this"
            di as error "block with the correct variable name before proceeding -"
            di as error "the tax-season triple-diff (Analysis do-file, Part III-B)"
            di as error "depends on it."
            exit 111
        }
    }
}
generate tax_season = inlist(month, 1, 2, 3, 4)
label variable tax_season "=1 if diary day falls Jan-Apr (approx. tax filing season)"
qui sum tax_season
di "Share of person-days in tax_season window (Jan-Apr): " %4.1f 100*r(mean) "%"
di "  (sanity check: should be roughly 4/12 = 33% if diary days are spread evenly across the year)"

*--- Individual-level treatment proxy ---
*  TREATED: income $50k-$100k (famincome 12-14) - pre-TCJA itemization ~43%
*  CONTROL: income < $35k (famincome <= 9)       - pre-TCJA itemization ~5-18%
*
*  We define two treatment dummies:
*   treatment_ind  = 1 for middle/upper-middle income (most likely switchers)
*   treatment_high = 1 for high income ($100k+; famincome >= 15)
*                    (likely already itemizing but may have been constrained by SALT cap)

generate treatment_ind = 0
replace  treatment_ind = 1 if famincome >= 12 & famincome <= 14
label variable treatment_ind "=1 if famincome $50k-$100k (DiD treated)"

generate treatment_high = 0
replace  treatment_high = 1 if famincome >= 15
label variable treatment_high "=1 if famincome $100k+ (high-income treated)"

generate control_group = 0
replace  control_group = 1 if famincome <= 9
label variable control_group "=1 if famincome <$35k (DiD control)"

*--- DiD interaction terms ---
generate did_ind    = treatment_ind * post_tcja
generate did_high   = treatment_high * post_tcja

label variable did_ind  "DiD: treatment_ind * post_tcja"
label variable did_high "DiD: treatment_high * post_tcja"

*--- NEW: triple-diff support variables (treatment x post x tax_season) ---
*   Lower-order interactions included so the triple-interaction coefficient
*   (did_x_season) is correctly identified. did_x_season is the KEY
*   coefficient for the tax-season robustness/mechanism test (Analysis
*   do-file, Part III-B): if the TCJA effect operates through filing
*   season as the paper's own story implies, did_ind (the effect OUTSIDE
*   tax season) should be near zero and did_x_season should pick up the
*   filing-season-specific effect.
generate treat_x_season = treatment_ind * tax_season
generate post_x_season  = post_tcja * tax_season
generate did_x_season   = did_ind * tax_season
label variable treat_x_season "Treatment_ind x Tax season"
label variable post_x_season  "Post_tcja x Tax season"
label variable did_x_season   "Triple-diff: Treatment x Post x Tax season"

*--- Event-study year dummies ---
*   t = 0  -> 2018 (TCJA effective Jan 1, 2018)
*   Base   = t = -1 -> 2017 (last full pre-reform year)
*   Window: -5/+5  ->  2013-2023
generate year_rel = year - 2018          // relative year (0 = TCJA effective)
label variable year_rel "Years relative to TCJA effective date (Jan 2018)"

forvalues t = -5/5 {
    if `t' != -1 {                                      // omit t = -1 (base 2017)
        local suffix = cond(`t' < 0, "m" + string(-`t'), string(`t'))
        generate event_yr_`suffix' = (year_rel == `t')
        label variable event_yr_`suffix' "Event year `t' (= `=`t'+2018')"
    }
}
*  Omit 2020 from event-study interactions (COVID confound)
generate covid = (year == 2020)

*--- Build married early (needed for homeowner_proxy below; rebuilt in STEP 5 if absent) ---
capture confirm variable married
if _rc != 0 {
    generate married = (marst == 1 | marst == 2)
    replace  married = 0 if married == .
    label variable married "=1 if married (spouse present or absent)"
}

*--- Homeownership proxy (ATUS has no direct variable; approximate) ---
*   Married households with children and mid-upper income are more likely owners
generate homeowner_proxy = (married == 1 & hh_numkids > 0 & famincome >= 12)
replace  homeowner_proxy = 1 if famincome >= 15   // high income -> likely owner
label variable homeowner_proxy "Proxy for homeownership (married + children + income)"

generate treatment_proxy = treatment_ind * homeowner_proxy
generate did_proxy = treatment_proxy * post_tcja
label variable treatment_proxy "Treatment * homeowner proxy"
label variable did_proxy "DiD with homeownership proxy"

*--- NEW: explicit DiD estimation-sample flag + diagnostic ---
*   Reviewer #2 (minor comment) flagged an apparent inconsistency: the text
*   (p.9) says the $35-50k "transition zone" (and >$100k) are excluded from
*   the full analysis, but the N's reported for Table 3 columns (2) "Full
*   controls" vs (3) "Clean sample" don't obviously square with that claim -
*   87,779 vs 53,954 is a much bigger gap than just dropping the transition
*   zone should produce, given famincome 1-16 are ALL still in this saved
*   dataset at this point (only famincome > 16 was dropped in STEP 2).
*   This block does NOT silently redefine the estimation sample used
*   elsewhere in the code (Table 2 columns 1-2 currently run on the FULL
*   1-16 famincome range, only column 3 restricts explicitly) - it just
*   makes the discrepancy visible so you can decide which side (paper text,
*   or Table 2 columns 1-2/4-6) needs to be corrected before resubmission.
generate in_did_sample = (treatment_ind == 1 | control_group == 1)
label variable in_did_sample "=1 if in treatment OR control group (excludes $35-50k transition zone & $100k+)"

di ""
di "=================================================================="
di "  DIAGNOSTIC: sample composition by famincome, for the Reviewer #2"
di "  'transition zone' consistency check (compare to paper Table 1/3)"
di "=================================================================="
tab famincome treatment_ind, missing
tab famincome control_group, missing
count
di "  Total person-days (famincome 1-16, no treat/control restriction)."
count if in_did_sample == 1
di "  Person-days if restricted to treatment OR control (excl. transition zone & >100k)."
count if treatment_ind == 1
count if control_group == 1
count if treatment_ind == 0 & control_group == 0 & treatment_high == 0
di "  ^ Person-days in the $35-50k 'transition zone' specifically."
count if treatment_high == 1
di "  ^ Person-days with income $100k+ ('high income', also NOT in treat/control)."
di "  If Table 2 columns (1)-(2) and (4)-(6) do not explicitly 'keep if"
di "  in_did_sample==1', the transition zone and/or high-income households"
di "  ARE currently part of the implicit comparison group in those columns -"
di "  this is very likely what the reviewer's Table 3 col.(2) vs col.(3) N"
di "  comparison picked up on. See Analysis_DiD_TCJA.do Part II."
di "=================================================================="
di ""


********************************************************************************
** STEP 4: MERGE STATE-LEVEL TREATMENT INTENSITY
********************************************************************************

*--- Merge state treatment data ---
rename statefip statefip_orig    // preserve original
gen statefip = statefip_orig

merge m:1 statefip using "Data/TCJA_State_Treatment.dta", ///
    keepusing(treat_intensity item2017 delta_1718 homeown_rate ///
              top_state_tax no_income_tax treat_quintile) ///
    keep(master match)
drop _merge

*--- Continuous DiD: state treatment intensity * post ---
generate did_state = treat_intensity * post_tcja
label variable did_state "Continuous DiD: state treat_intensity * post_tcja"

*--- High SALT exposure states (top quintile of pre-TCJA itemization) ---
generate high_salt_state = (treat_quintile == 5)
generate did_salt = high_salt_state * post_tcja
label variable high_salt_state "= 1 if state in top quintile of pre-TCJA itemization"
label variable did_salt "DiD: high_salt_state * post_tcja"

*--- NEW: data-driven itemization-decline diagnostic (magnitude check) ---
*   Reviewer #1 (pt.4) computed an implied treatment-on-the-treated effect
*   using an ASSUMED ~30pp itemization gap from Tax Foundation (2019)
*   figures. Here we compute the analogous gap directly from the merged
*   IRS SOI state-level data (delta_1718 = state pp change in itemization,
*   2017->2018) for the treatment vs control group, so the Analysis
*   do-file's magnitude/plausibility check (Part VIII-B) uses a
*   data-driven number instead of an assumption. NOTE: this is a
*   STATE-level average, not individual switcher status (ATUS has no
*   itemization variable) - treat it as an approximation, not a precise
*   treatment-on-the-treated estimate.
preserve
    collapse (mean) delta_1718 [aw = wt06], by(treatment_ind control_group)
    di ""
    di "--- Mean state-level pp change in itemization rate, 2017->2018, by group ---"
    list, clean noobs
    di "(treatment_ind==1 row: treated group; control_group==1 row: control group;"
    di " both 0: transition zone/high income, not used in main DiD)"
    di ""
restore


********************************************************************************
** STEP 5: STANDARD DEMOGRAPHIC CONTROLS
** (identical to original paper's Analysis_Total_Time.do)
********************************************************************************

generate working   = (empstat == 1)
generate full_time = 1 if fullpart == 1
replace  full_time = 0 if fullpart == 2
replace  full_time = 0 if working == 0

generate educ_1 = (educ < 20)
generate educ_2 = (educ == 20 | educ == 21)
generate educ_3 = (educ > 21)

generate hispanic = 0 if hisp == 100
replace  hispanic = 1 if hispanic == .

*--- married already created in STEP 3 (before homeowner_proxy); skip if present ---
capture confirm variable married
if _rc != 0 {
    generate married = (marst == 1 | marst == 2)
    replace  married = 0 if married == .
}

capture drop asian
generate white       = (race == 100)
generate black       = (race == 110)
generate indian      = (race == 120)
generate asian       = (race == 131)
generate pacific     = (race == 132)
generate other_races = (race >= 200 & race < 300)

foreach v of varlist white black indian asian pacific other_races {
    replace `v' = 0 if `v' == .
}

generate male = (sex == 1)
replace  male = 0 if sex == 2

replace retired = 0 if retired > 1

generate male_full_time = male * full_time

*--- Income dummies ---
tab famincome, gen(famincome_)

*--- Year trend (centered at first sample year) ---
generate year_c  = year - 2013    // centered year (base = 2013)
generate year_c2 = year_c ^ 2 / 100


********************************************************************************
** STEP 6: SAVE TIME-USE SAMPLE
********************************************************************************

save "Data/TCJA_Financial_Time.dta", replace
di "TCJA_Financial_Time.dta saved - N = `e(N)' (approx)"


********************************************************************************
** STEP 7: BUILD WELL-BEING SAMPLE
** (ATUS WBM available: 2010, 2012, 2013, 2021)
** Pre-period: 2013  |  Post-period: 2021
********************************************************************************

clear
use "Data/ATUS_Clean.dta", clear

*--- Keep WBM-eligible years only ---
keep if inlist(year, 2010, 2012, 2013, 2021)

*--- Employment filter ---
drop if empstat == 2
rename clwkr class_of_worker
generate government_worker    = inlist(class_of_worker, 1, 2, 3)
generate private_worker       = inlist(class_of_worker, 4, 5)
generate self_employed_worker = inlist(class_of_worker, 6, 7)
foreach v of varlist government_worker private_worker self_employed_worker {
    replace `v' = 0 if `v' == .
}

*--- Activity classifications (FULL set, identical to STEP 2) ---
*   Required to compute total_time = 1440 per person-day before WBM filter
generate financial_act = 1 if inlist(activity, ///
    20901, 20902, 80201, 80202, 80203, 80299, 100103, 180802)

*--- NEW: narrow tax/insurance activity, for parity with the time-use sample ---
generate tax_act = 1 if inlist(activity, 20902, 100103)

generate personal_care_act = 1 if inlist(activity, ///
    10101,10102,10199,10201,10299,10301,10399,10401,10499,10501,10599,19999, ///
    80401,80402,80403,80499,80501,80502,80599,110101,110201,110299,119999, ///
    180101,180199,180804,180805,180899,181101,181199)

generate housework_act = 1 if inlist(activity, ///
    20101,20102,20103,20104,20199,20201,20202,20203,20299,20301,20302,20303,20399, ///
    20401,20402,20499,20501,20502,20599,20601,20602,20603,20699,20701,20799,20801,20899, ///
    20903,20904,20905,20999,29999,40501,40502,40503,40504,40505,40506,40507,40508,40599,49999, ///
    70101,70102,70103,70104,70105,70199,70201,70299,70301,70399,79999,80301,80302,80399, ///
    80601,80602,80699,80701,80702,80799,80801,89999,90101,90102,90103,90104,90199,90201,90202, ///
    90299,90301,90302,90399,90401,90402,90499,90501,90502,90599,99999,100101,100102,100199, ///
    100201,100299,100303,100304,100399,100401,100499,109999,180201,180202,180203,180204,180205, ///
    180206,180207,180208,180209,180299,180701,180702,180703,180704,180705,180799,180801,180803, ///
    180806,180807,180901,180902,180903,180904,180905,180999,181001,181002,181099)

generate childcare_act = 1 if inlist(activity, ///
    30101,30102,30103,30104,30105,30106,30107,30108,30109,30110,30111,30112,30199, ///
    30201,30202,30203,30204,30299,30301,30302,30303,30399,30401,30402,30403,30404,30405,30499, ///
    40101,40102,40103,40104,40105,40106,40107,40108,40109,40110,40111,40112,40199, ///
    40201,40202,40203,40204,40299,40301,40302,40303,40399,80101,80102,80199, ///
    180301,180302,180303,180304,180401,180402,180403,180404)

generate adult_care_act = 1 if inlist(activity, ///
    30501,30502,30503,30504,30599,39999,40401,40402,40403,40404,40405,40499, ///
    180305,180306,180307,180399,180405,180406,180407,180499)

generate market_work_act = 1 if inlist(activity, ///
    50101,50102,50103,50104,50199,50201,50202,50203,50204,50205,50299, ///
    50301,50302,50303,50304,50305,50399,50401,50403,50404,50405,50499,59999, ///
    180501,180502,180503,180504,180599)

generate study_act = 1 if inlist(activity, ///
    60101,60102,60103,60104,60199,60201,60202,60203,60204,60299,60301,60302,60303,60399, ///
    60401,60402,60403,60499,69999,180601,180602,180603,180604,180605,180699)

generate leisure_act = 1 if inlist(activity, ///
    120101,120199,120201,120202,120299,120301,120302,120303,120304,120305,120306,120307, ///
    120308,120309,120310,120311,120312,120313,120399,120401,120402,120403,120404,120405,120499, ///
    120501,120502,120503,120504,120599,129999,130101,130102,130103,130104,130105,130106,130107, ///
    130108,130109,130110,130111,130112,130113,130114,130115,130116,130117,130118,130119,130120, ///
    130121,130122,130123,130124,130125,130126,130127,130128,130129,130130,130131,130132,130133, ///
    130134,130135,130136,130199,130201,130202,130203,130204,130205,130206,130207,130209,130210, ///
    130211,130212,130213,130214,130215,130216,130217,130218,130219,130220,130221,130222,130223, ///
    130224,130225,130226,130227,130229,130230,130231,130232,130299,130301,130302,130399,130401, ///
    130402,139999,140101,140102,140103,140104,140105,149999,150101,150102,150103,150104,150105, ///
    150106,150199,150201,150202,150203,150204,150299,150301,150302,150399,150401,150402,150499, ///
    150501,150599,150601,150602,150699,150701,150799,150801,150899,159999,160101,160102,160103, ///
    160104,160105,160106,160107,160108,160199,160201,160299,169999,181201,181202,181203,181204, ///
    181205,181206,181299,181301,181302,181399,181401,181499,181501,181599,181601,181699, ///
    181801,181899,189999)

foreach v of varlist personal_care_act housework_act financial_act tax_act childcare_act ///
                       adult_care_act market_work_act study_act leisure_act {
    replace `v' = 0 if `v' == .
}

*--- Aggregate time per activity category (BEFORE WBM filter, on ALL episodes) ---
foreach act in personal_care housework financial childcare adult_care ///
               market_work study leisure {
    generate `act'_time = duration if `act'_act == 1
    replace  `act'_time = 0 if `act'_time == .
}

sort caseid
foreach act in personal_care housework financial childcare adult_care ///
               market_work study leisure {
    by caseid: egen `act' = sum(`act'_time)
}

*--- NEW: narrow tax/insurance time, well-being sample (parity with STEP 2) ---
generate tax_time = duration if tax_act == 1
replace  tax_time = 0 if tax_time == .
sort caseid
by caseid: egen tax = sum(tax_time)
label variable tax "Daily minutes: tax prep/filing + insurance claims (narrow outcome)"

generate total_time = personal_care + housework + financial + childcare + ///
                      adult_care + market_work + study + leisure

*--- Now filter to WBM-eligible episodes ---
keep if wbelig == 1
drop if schappy > 6

*--- Drop extreme well-being ratings ---
foreach v of varlist schappy scsad scpain sctired scstress meaning {
    capture drop if `v' > 6
}

*--- Wages ---
replace earnweek = . if earnweek == 0 | earnweek == 99999.99
replace hourwage = . if hourwage == 0 | hourwage == 999.99
gen wage = hourwage if hourwage != .
replace wage = earnweek / uhrsworkt if wage == . & earnweek != .

drop if famincome > 16
replace ageychild = 0 if ageychild > 17
generate age_2 = (age * age) / 100
drop if total_time < 1440
replace wt06 = wt20 if wt06 == .

*--- DiD variables for well-being ---
*   Pre: 2010, 2012, 2013  |  Post: 2021
generate post_tcja = (year == 2021)
label variable post_tcja "=1 if year == 2021 (post-TCJA WBM wave)"

generate treatment_ind  = (famincome >= 12 & famincome <= 14)
generate treatment_high = (famincome >= 15)
generate did_ind  = treatment_ind  * post_tcja
generate did_high = treatment_high * post_tcja
label variable did_ind  "DiD: treatment_ind * post_tcja (WBM)"
label variable did_high "DiD: treatment_high * post_tcja (WBM)"

*--- Demographics (same as above) ---
generate working    = (empstat == 1)
generate full_time  = (fullpart == 1)
replace  full_time  = 0 if working == 0
generate educ_1 = (educ < 20)
generate educ_2 = (educ == 20 | educ == 21)
generate educ_3 = (educ > 21)
generate hispanic = 0 if hisp == 100
replace  hispanic = 1 if hispanic == .
generate married = (marst == 1 | marst == 2)
replace  married = 0 if married == .
capture drop asian
generate white       = (race == 100)
generate black       = (race == 110)
generate indian      = (race == 120)
generate asian       = (race == 131)
generate pacific     = (race == 132)
generate other_races = (race >= 200 & race < 300)
foreach v of varlist white black indian asian pacific other_races {
    replace `v' = 0 if `v' == .
}
generate male           = (sex == 1)
replace  male           = 0 if sex == 2
replace  retired        = 0 if retired > 1
generate male_full_time = male * full_time
tab famincome, gen(famincome_)
generate year_c = year - 2013

*--- Merge state treatment ---
rename statefip statefip_orig
gen statefip = statefip_orig
merge m:1 statefip using "Data/TCJA_State_Treatment.dta", ///
    keepusing(treat_intensity treat_quintile) ///
    keep(master match)
drop _merge

generate did_state = treat_intensity * post_tcja
capture generate high_salt_state = (treat_quintile == 5)
generate did_salt  = high_salt_state * post_tcja

save "Data/TCJA_Financial_WellBeing.dta", replace
di "TCJA_Financial_WellBeing.dta saved."

di ""
di "===================================================================="
di "  Sample creation complete. Next: run Analysis_DiD_TCJA.do"
di "===================================================================="
