/*******************************************************************************
*
*  Analysis_DiD_TCJA.do
*
*  PURPOSE: Estimate causal effects of TCJA financial complexity reduction
*    on time use (H1, H3) and emotional well-being (H2, H3)
*
*  PAPER: "Causal Effects of Financial Complexity Shocks on Time Use and
*          Emotional Well-Being: Evidence from Tax Policy Changes (TCJA 2017)"
*
*  REQUIRES:
*    - Data/TCJA_Financial_Time.dta       (from Sample_Creation_TCJA.do)
*    - Data/TCJA_Financial_WellBeing.dta  (from Sample_Creation_TCJA.do)
*    - outreg2 package (ssc install outreg2)
*    - coefplot  package (ssc install coefplot)
*    - estout    package (ssc install estout)
*
*  EVENT-STUDY CONVENTION:
*    - Sample period: 2013-2023 (-5/+5 window around TCJA)
*    - t = 0  -> 2018 (TCJA effective Jan 1, 2018)
*    - Base   = t = -1 -> 2017 (omitted year in event study)
*    - 2020 omitted from event-study interactions (COVID confound)
*
*  STRUCTURE:
*    Part I     - Table 1: Summary statistics
*    Part II    - Table 2: Main DiD (H1: time in financial activities)
*    Part III   - Table 3: Event study / parallel trends test (Figure 1)
*    Part III-B - Table 9: Tax-season triple-diff  [NEW]
*    Part IV    - Table 4: DiD by gender (H3) (Figure 2a, 2b)
*    Part IV-B  - Table 10: Event studies for college+ and high-SALT subgroups [NEW]
*    Part V     - Table 5: Well-being DiD (H2)
*    Part VI    - Table 6: Heterogeneity by education, SALT exposure, gender
*    Part VII   - Table 7: Continuous DiD (state treatment intensity)
*    Part VIII  - Table 8: Robustness checks
*    Part VIII-B- Magnitude plausibility check & minimum detectable effect [NEW]
*    Part IX    - Figures (Figure 3 trends, Figure 4 by gender)
*
*  REVISION HISTORY (response to JEBO reviewer comments, Aug 2026):
*    - NEW Table2 cols (7)-(8): narrow tax/insurance outcome (Rev#2), and
*      pre-COVID-only post period 2013-2019 (Rev#1 pt.1b).
*    - NEW Part III-B / Table9: treatment x post x tax_season triple-diff,
*      on both the broad and narrow outcomes (Rev#1 pt.3, Rev#2 "tax
*      season" comment). Requires tax_season / did_x_season etc. from the
*      updated Sample_Creation_TCJA.do.
*    - NEW Part IV-B / Table10 + Figures 5-6: event studies + joint
*      pre-trend tests for the college-educated and high-SALT subgroups
*      (Rev#2: "we need to see parallel trends tests for the heterogeneous
*      effects that look significant").
*    - NEW Part VIII-B: minimum detectable effect (Rev#2 "statistical
*      power") and a data-driven implied-ATT/switcher magnitude check
*      against the IRS Tax Burden Survey benchmark (Rev#1 pt.4).
*    - See Sample_Creation_TCJA.do STEP 3 for a diagnostic block on the
*      "transition zone" sample-consistency issue (Rev#2 minor comment) -
*      resolve that BEFORE trusting Table 2 columns (1)-(2)/(4)-(6) here,
*      since they currently do NOT restrict to `in_did_sample==1`.
*
*  AUTHOR: [Your name]
*  LAST UPDATED: 2026
*
*******************************************************************************/

clear
set more off
capture ssc install outreg2
capture ssc install coefplot
capture ssc install estout

*--- Controls used throughout ---
global controls "male age age_2 full_time male_full_time educ_2 educ_3 hispanic married white black indian asian pacific other_races retired hh_size hh_numkids ageychild i.famincome"

global controls_noinc "male age age_2 full_time male_full_time educ_2 educ_3 hispanic married white black indian asian pacific other_races retired hh_size hh_numkids ageychild"


*log using "Results/All_Results.log", replace

********************************************************************************
** PART I - SUMMARY STATISTICS (Table 1 & Table 1b)
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear



di "--- Panel A: Time use (minutes/day) ---"
sum financial tax personal_care housework childcare adult_care market_work study leisure  [aw = wt06]

di "--- Panel B: Demographics ---"
sum male age full_time educ_1 educ_2 educ_3 hispanic married ///
    white black indian asian pacific other_races retired ///
    hh_size hh_numkids ageychild [aw = wt06]

di "--- Panel C: Treatment group breakdown ---"
tab famincome, sum(financial)
tab post_tcja treatment_ind, sum(financial)

di "--- Panel D: Pre vs Post financial time by treatment group ---"
bysort post_tcja treatment_ind: sum financial [aw = wt06]



********************************************************************************
** PART II - MAIN DiD: FINANCIAL TIME (Table 2) - Tests H1
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- IMPORTANT [confirmed by the Sample_Creation_TCJA.do STEP 3 diagnostic] ---
*   Columns (1),(2),(4),(5),(6) below do NOT restrict the sample to
*   treatment_ind==1 | control_group==1. Since STEP 2 only drops
*   famincome>16 (not the $35-50k transition zone or the $100k+ group),
*   "post_tcja"/"did_ind" in those columns are estimated against a
*   contaminated comparison group = control_group (famincome<=9, N=27,129)
*   PLUS the $35-50k transition zone (N=11,553) PLUS the $100k+ group
*   (N=22,272) - i.e. against everyone NOT in the $50-100k bracket, not
*   against the "rarely itemize" <$35k group the paper's text describes.
*   This is very likely the exact source of the Table 1 vs Table 3 N
*   mismatch Reviewer #2 flagged (87,779 vs 53,954): 53,954 = 26,825
*   (treated) + 27,129 (true control) is the CORRECT clean comparison, and
*   it is already what column (3) below computes. Column (3), NOT column
*   (2), is the specification consistent with the paper's stated design -
*   treat column (2) as a robustness check against a broader comparison
*   group, not as the preferred estimate, when revising the text.

*--- Column 1: Simple DiD, no controls [vs ALL non-treated - see note above] ---
reg financial did_ind treatment_ind post_tcja i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(1) Simple DiD") ///
    keep(did_ind treatment_ind post_tcja) ///
    addtext("Controls","No","State FE","Yes","Year FE","Yes","Comparison","vs ALL non-treated (NOT clean control)") ///
    bdec(3) se replace

*--- Column 2: With demographics [vs ALL non-treated - see note above] ---
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(2) With Controls") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Comparison","vs ALL non-treated (NOT clean control)") ///
    bdec(3) se append

*--- Column 3: Treatment = $50k-$100k vs. control = <$35k ---
*   PREFERRED SPECIFICATION - the only column that restricts to the two
*   groups the paper's identification strategy actually describes
*   (excludes $35-50k transition zone AND $100k+ high income).
preserve
keep if treatment_ind == 1 | control_group == 1
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(3) Clean Comparison") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Sample","50-100k vs <35k","Comparison","PREFERRED: clean treat vs true control") ///
    bdec(3) se append
restore

*--- Column 4: High-income group ($100k+) ---
reg financial did_high treatment_high post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(4) High Income") ///
    keep(did_high treatment_high post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Treatment","Income $100k+") ///
    bdec(3) se append

*--- Column 5: Homeownership proxy ---
reg financial did_proxy treatment_proxy post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(5) With Homeown. Proxy") ///
    keep(did_proxy treatment_proxy post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes") ///
    bdec(3) se append

*--- Column 6: Excluding 2020 (COVID year) ---
preserve
drop if year == 2020
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(6) Excl. 2020") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Note","2020 excluded") ///
    bdec(3) se append
restore

*--- Column 7 [NEW]: Narrow outcome - tax/insurance time only ---
*   Reviewer #2: higher-powered test using only the activity codes that
*   plausibly respond to the standard-deduction change (tax prep/filing +
*   insurance), instead of all financial management. Same sample/spec as
*   column (2).
reg tax did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(7) Narrow: Tax Time") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Outcome","Tax/insurance minutes only") ///
    bdec(3) se append

*--- Column 8 [NEW]: Pre-COVID post period only (2013-2019) ---
*   Reviewer #1 pt.1b: the post-period overlaps COVID; excluding 2020 alone
*   (column 6) still leaves 2021-2023 (pandemic-adjacent recovery years) in
*   the post period. This restricts to a "clean" pre-COVID post window.
preserve
keep if year <= 2019
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(8) Pre-COVID Post Only") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Sample","2013-2019 only") ///
    bdec(3) se append
restore

*--- Column 9 [NEW]: Narrow outcome (tax) x clean comparison sample ---
*   Combines Reviewer #2's narrow-outcome suggestion (col 7) with the
*   correct treat-vs-true-control sample restriction (col 3) - this is
*   the specification the paper should probably lead with going forward,
*   since it addresses both the identification concern AND the power
*   concern in one shot.
preserve
keep if treatment_ind == 1 | control_group == 1
reg tax did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(9) Narrow Tax x Clean Sample") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Sample","50-100k vs <35k","Outcome","Tax/insurance minutes only","Comparison","PREFERRED sample + narrow outcome") ///
    bdec(3) se append
restore



********************************************************************************
** PART III - EVENT STUDY / PARALLEL TRENDS (Table 3 & Figure 1) - Tests H1
********************************************************************************
**  Window: -5/+5  ->  2013-2023
**  Base year: 2017 (t = -1, omitted)
**  2020 omitted from event-study interactions (COVID confound)
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear


*--- Generate treatment x year interactions ---
*   Base = 2017 (omitted), exclude 2020 (COVID confound)
levelsof year, local(years)
foreach yr of local years {
    generate treat_yr_`yr' = treatment_ind * (year == `yr')
}
drop treat_yr_2017       // base year (t = -1)
capture drop treat_yr_2020   // COVID year - absorbed via i.year FE

*--- Event study regression (window: -5/+5, base = 2017) ---
reg financial treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
    treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023 ///
    treatment_ind post_tcja $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)

*--- Export coefficients for plotting ---
parmest, saving("Results/EventStudy_coefs.dta", replace) label

*--- Joint test: pre-reform coefficients = 0 (parallel trends) ---
test treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016
di "Joint test pre-reform placebo (p-value above): should be > 0.10 for parallel trends"

outreg2 using "Results/Table3_EventStudy.xls", ///
    ctitle("Event Study") ///
    keep(treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
         treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023) ///
    bdec(3) se replace


*--- Figure 1: Event study plot (vertical layout, professional style) ---
*   9 coefficients in order: 2013, 2014, 2015, 2016, [2017 base], 2018, 2019,
*   [2020 omitted COVID], 2021, 2022, 2023
*   Vertical layout: year on x-axis, coefficient on y-axis
coefplot, ///
    keep(treat_yr_*) vertical ///
    rename(treat_yr_2013 = "2013" treat_yr_2014 = "2014" treat_yr_2015 = "2015" ///
           treat_yr_2016 = "2016" treat_yr_2018 = "2018" treat_yr_2019 = "2019" ///
           treat_yr_2021 = "2021" treat_yr_2022 = "2022" treat_yr_2023 = "2023") ///
    ciopts(recast(rcap) lcolor(gs8) lwidth(medium)) ///
    mcolor("26 71 111") msymbol(O) msize(medlarge) ///
    yline(0, lpattern(solid) lcolor(black) lwidth(thin)) ///
    xline(4.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
    title("Event Study: Effect of TCJA on Time in Financial Activities", size(medium)) ///
    subtitle("Treatment x Year coefficients (reference year: 2017)", size(small)) ///
    ytitle("Treatment x Year coefficient (minutes/day)", size(small)) ///
    xtitle("Year", size(small)) ///
    ylabel(, angle(0) format(%5.1f) gmin gmax) ///
    xlabel(, angle(45)) ///
    legend(off) ///
    note("Coefficients from event-study regression (eq. 1) estimated jointly." ///
         "Reference year: 2017 (last pre-reform year). 2020 omitted (COVID-19 confound)." ///
         "95% CI. Controls include demographics, state FE, year FE. SEs clustered at state level." ///
         "Dashed red line: TCJA effective (Jan 2018).", size(vsmall)) ///
    graphregion(color(white) margin(medium)) plotregion(margin(medium)) ///
    scheme(s2color)
graph export "Results/Figure1_EventStudy.png", replace width(2400)


********************************************************************************
** PART III-B [NEW] - TAX SEASON TRIPLE-DIFF (Table 9)
********************************************************************************
**  Reviewer #1 (pt.3) and Reviewer #2 both suggest exploiting within-year
**  timing: the standard-deduction change should only plausibly affect time
**  use during the filing season (~Jan-Apr), not the full calendar year.
**  This estimates treatment x post x tax_season, on both the broad outcome
**  (financial) and the narrow outcome (tax), so the paper can report
**  whether the effect concentrates where the mechanism predicts it should.
**  Requires tax_season / treat_x_season / post_x_season / did_x_season
**  from the updated Sample_Creation_TCJA.do (STEP 3) - re-run that script
**  first if these variables are missing.
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

capture confirm variable did_x_season
if _rc != 0 {
    di as error "ERROR: did_x_season not found - re-run the updated"
    di as error "Sample_Creation_TCJA.do (STEP 3) before this section."
    exit 111
}

*--- (1) Broad outcome (all financial management), triple-diff ---
reg financial did_ind did_x_season treatment_ind post_tcja tax_season ///
    treat_x_season post_x_season $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
di ""
di "--- Broad outcome: total effect DURING tax season (did_ind + did_x_season) ---"
lincom did_ind + did_x_season
outreg2 using "Results/Table9_TaxSeason_TripleDiD.xls", ///
    ctitle("(1) Broad Outcome") ///
    keep(did_ind did_x_season treatment_ind post_tcja tax_season ///
         treat_x_season post_x_season $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Outcome","All financial mgmt") ///
    bdec(3) se replace

*--- (2) Narrow outcome (tax/insurance time only), triple-diff ---
*   Sharpest test: if the mechanism is filing-driven, this effect should be
*   concentrated almost entirely in did_x_season, with did_ind near zero.
reg tax did_ind did_x_season treatment_ind post_tcja tax_season ///
    treat_x_season post_x_season $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
di ""
di "--- Narrow (tax) outcome: total effect DURING tax season (did_ind + did_x_season) ---"
lincom did_ind + did_x_season
outreg2 using "Results/Table9_TaxSeason_TripleDiD.xls", ///
    ctitle("(2) Narrow: Tax Time") ///
    keep(did_ind did_x_season treatment_ind post_tcja tax_season ///
         treat_x_season post_x_season $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Outcome","Tax/insurance minutes only") ///
    bdec(3) se append

*--- (3) [NEW] Broad outcome, restricted to the CLEAN comparison sample ---
*   Columns (1)-(2) above run on the full famincome 1-16 range, so
*   treat_x_season/did_x_season are picking up "treated vs everyone else"
*   (transition zone + high income included), same contamination issue as
*   Table 2 columns (1)-(2) - see the note at the top of Part II. This
*   column restricts to treatment_ind==1 | control_group==1 so the
*   tax-season test is run on the sample the paper's design actually
*   describes. Compare directly to Table 2 column (3).
preserve
keep if treatment_ind == 1 | control_group == 1
reg financial did_ind did_x_season treatment_ind post_tcja tax_season ///
    treat_x_season post_x_season $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
di ""
di "--- CLEAN SAMPLE, broad outcome: total effect DURING tax season ---"
lincom did_ind + did_x_season
outreg2 using "Results/Table9_TaxSeason_TripleDiD.xls", ///
    ctitle("(3) Broad, Clean Sample") ///
    keep(did_ind did_x_season treatment_ind post_tcja tax_season ///
         treat_x_season post_x_season $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Outcome","All financial mgmt","Sample","PREFERRED: 50-100k vs <35k") ///
    bdec(3) se append
restore

*--- (4) [NEW] Narrow outcome, restricted to the CLEAN comparison sample ---
*   The sharpest available test: narrow outcome + correct comparison group.
preserve
keep if treatment_ind == 1 | control_group == 1
reg tax did_ind did_x_season treatment_ind post_tcja tax_season ///
    treat_x_season post_x_season $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
di ""
di "--- CLEAN SAMPLE, narrow (tax) outcome: total effect DURING tax season ---"
lincom did_ind + did_x_season
outreg2 using "Results/Table9_TaxSeason_TripleDiD.xls", ///
    ctitle("(4) Narrow, Clean Sample") ///
    keep(did_ind did_x_season treatment_ind post_tcja tax_season ///
         treat_x_season post_x_season $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Outcome","Tax/insurance minutes only","Sample","PREFERRED: 50-100k vs <35k") ///
    bdec(3) se append
restore

di ""
di "--- Interpretation guide for Table 9 ---"
di "  did_ind      = effect OUTSIDE tax season (expect ~0 if mechanism is filing-driven)"
di "  did_x_season = ADDITIONAL effect DURING tax season (key coefficient)"
di "  did_ind + did_x_season (see lincom above) = total effect DURING tax season"
di "  Columns (3)-(4) are on the PREFERRED clean sample - read those over (1)-(2)."
di ""


********************************************************************************
** PART IV - HETEROGENEITY BY GENDER (Table 4) - Tests H3
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear


*--- Triple interaction: DiD x Male ---
generate did_ind_male   = did_ind   * male
generate did_high_male  = did_high  * male
generate did_ind_female = did_ind   * (1 - male)
label variable did_ind_male   "DiD x Male (financial time)"
label variable did_ind_female "DiD x Female (financial time)"

*--- Column 1: Full sample with gender interaction ---
reg financial did_ind treatment_ind post_tcja male ///
    did_ind_male c.male#c.treatment_ind c.male#c.post_tcja ///
    age age_2 full_time male_full_time educ_2 educ_3 hispanic ///
    married white black indian asian pacific other_races retired ///
    hh_size hh_numkids ageychild i.famincome i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table4_Gender.xls", ///
    ctitle("(1) Full Sample + Gender Interaction") ///
    keep(did_ind did_ind_male treatment_ind post_tcja male ///
         age age_2 full_time educ_2 educ_3 hispanic married ///
         white black retired hh_size hh_numkids ageychild) ///
    bdec(3) se replace

*--- Column 2: Women only ---
preserve
keep if male == 0
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table4_Gender.xls", ///
    ctitle("(2) Women Only") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Sample","Women only") bdec(3) se append
restore

*--- Column 3: Men only ---
preserve
keep if male == 1
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table4_Gender.xls", ///
    ctitle("(3) Men Only") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Sample","Men only") bdec(3) se append
restore

*--- Figure 2: Gender-specific event study (vertical layout) ---
foreach g in 0 1 {
    local lbl  = cond(`g' == 1, "Men", "Women")
    local labl = cond(`g' == 1, "Men only", "Women only")
    preserve
    keep if male == `g'
    levelsof year, local(years)
    foreach yr of local years {
        generate treat_yr_`yr' = treatment_ind * (year == `yr')
    }
    drop treat_yr_2017
    capture drop treat_yr_2020
    reg financial treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
        treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023 ///
        treatment_ind post_tcja $controls i.year i.statefip ///
        [pw = wt06], robust cluster(statefip)
    coefplot, ///
        keep(treat_yr_*) vertical ///
        rename(treat_yr_2013 = "2013" treat_yr_2014 = "2014" treat_yr_2015 = "2015" ///
               treat_yr_2016 = "2016" treat_yr_2018 = "2018" treat_yr_2019 = "2019" ///
               treat_yr_2021 = "2021" treat_yr_2022 = "2022" treat_yr_2023 = "2023") ///
        ciopts(recast(rcap) lcolor(gs8) lwidth(medium)) ///
        mcolor("26 71 111") msymbol(O) msize(medlarge) ///
        yline(0, lpattern(solid) lcolor(black) lwidth(thin)) ///
        xline(4.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
        title("Event Study by Gender: `lbl'", size(medium)) ///
        subtitle("Treatment x Year coefficients (reference year: 2017)", size(small)) ///
        ytitle("Treatment x Year coefficient (minutes/day)", size(small)) ///
        xtitle("Year", size(small)) ///
        ylabel(, angle(0) format(%5.1f)) ///
        xlabel(, angle(45)) ///
        legend(off) ///
        note("Sample: `labl'. Coefficients from event-study regression (eq. 1)." ///
             "Reference year: 2017. 2020 omitted (COVID-19)." ///
             "95% CI. Controls include demographics, state FE, year FE. SEs clustered at state level." ///
             "Dashed red line: TCJA effective (Jan 2018).", size(vsmall)) ///
        graphregion(color(white) margin(medium)) plotregion(margin(medium)) ///
        scheme(s2color)
    graph export "Results/Figure2_EventStudy_`lbl'.png", replace width(2400)
    restore
}


********************************************************************************
** PART IV-B [NEW] - EVENT STUDIES FOR SIGNIFICANT SUBGROUPS (Table 10)
********************************************************************************
**  Reviewer #2: "We need to see parallel trends tests for the
**  heterogeneous effects that look significant (e.g. college educated
**  individuals in Table 6)." This mirrors the gender event-study loop
**  above (Part IV) for the college-educated and high-SALT subgroups,
**  where Table 6 reports significant DiD coefficients, WITH their own
**  joint pre-trend test - without this, a "significant" subgroup result
**  could simply be riding a pre-existing subgroup-specific trend.
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- College-educated only ---
preserve
keep if educ_3 == 1
levelsof year, local(years)
foreach yr of local years {
    generate treat_yr_`yr' = treatment_ind * (year == `yr')
}
drop treat_yr_2017
capture drop treat_yr_2020
reg financial treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
    treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023 ///
    treatment_ind post_tcja $controls_noinc i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
test treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016
di "Joint pre-trend test, COLLEGE-EDUCATED subgroup (p-value above; want p > 0.10)"
outreg2 using "Results/Table10_Subgroup_EventStudy.xls", ///
    ctitle("College+ : Event Study") ///
    keep(treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
         treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023) ///
    addtext("Subgroup","College-educated") bdec(3) se replace
coefplot, ///
    keep(treat_yr_*) vertical ///
    rename(treat_yr_2013 = "2013" treat_yr_2014 = "2014" treat_yr_2015 = "2015" ///
           treat_yr_2016 = "2016" treat_yr_2018 = "2018" treat_yr_2019 = "2019" ///
           treat_yr_2021 = "2021" treat_yr_2022 = "2022" treat_yr_2023 = "2023") ///
    ciopts(recast(rcap) lcolor(gs8) lwidth(medium)) ///
    mcolor("26 71 111") msymbol(O) msize(medlarge) ///
    yline(0, lpattern(solid) lcolor(black) lwidth(thin)) ///
    xline(4.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
    title("Event Study: College-Educated Subgroup", size(medium)) ///
    subtitle("Treatment x Year coefficients (reference year: 2017)", size(small)) ///
    ytitle("Treatment x Year coefficient (minutes/day)", size(small)) ///
    xtitle("Year", size(small)) ///
    ylabel(, angle(0) format(%5.1f)) xlabel(, angle(45)) legend(off) ///
    note("Sample: College-educated only. Reference year: 2017. 2020 omitted (COVID-19).", size(vsmall)) ///
    graphregion(color(white) margin(medium)) plotregion(margin(medium)) scheme(s2color)
graph export "Results/Figure5_EventStudy_CollegePlus.png", replace width(2400)
restore

*--- High-SALT states only ---
preserve
keep if high_salt_state == 1
levelsof year, local(years)
foreach yr of local years {
    generate treat_yr_`yr' = treatment_ind * (year == `yr')
}
drop treat_yr_2017
capture drop treat_yr_2020
reg financial treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
    treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023 ///
    treatment_ind post_tcja $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
test treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016
di "Joint pre-trend test, HIGH-SALT STATES subgroup (p-value above; want p > 0.10)"
outreg2 using "Results/Table10_Subgroup_EventStudy.xls", ///
    ctitle("High-SALT : Event Study") ///
    keep(treat_yr_2013 treat_yr_2014 treat_yr_2015 treat_yr_2016 ///
         treat_yr_2018 treat_yr_2019 treat_yr_2021 treat_yr_2022 treat_yr_2023) ///
    addtext("Subgroup","High-SALT states") bdec(3) se append
coefplot, ///
    keep(treat_yr_*) vertical ///
    rename(treat_yr_2013 = "2013" treat_yr_2014 = "2014" treat_yr_2015 = "2015" ///
           treat_yr_2016 = "2016" treat_yr_2018 = "2018" treat_yr_2019 = "2019" ///
           treat_yr_2021 = "2021" treat_yr_2022 = "2022" treat_yr_2023 = "2023") ///
    ciopts(recast(rcap) lcolor(gs8) lwidth(medium)) ///
    mcolor("26 71 111") msymbol(O) msize(medlarge) ///
    yline(0, lpattern(solid) lcolor(black) lwidth(thin)) ///
    xline(4.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
    title("Event Study: High-SALT States Subgroup", size(medium)) ///
    subtitle("Treatment x Year coefficients (reference year: 2017)", size(small)) ///
    ytitle("Treatment x Year coefficient (minutes/day)", size(small)) ///
    xtitle("Year", size(small)) ///
    ylabel(, angle(0) format(%5.1f)) xlabel(, angle(45)) legend(off) ///
    note("Sample: High-SALT states only (top quintile pre-TCJA itemization). Reference year: 2017. 2020 omitted.", size(vsmall)) ///
    graphregion(color(white) margin(medium)) plotregion(margin(medium)) scheme(s2color)
graph export "Results/Figure6_EventStudy_HighSALT.png", replace width(2400)
restore



********************************************************************************
** PART V - WELL-BEING DiD (Table 5) - Tests H2
********************************************************************************

use "Data/TCJA_Financial_WellBeing.dta", clear

*--- Summary statistics by activity and period ---
di "--- Mean well-being during financial activities by treatment x post ---"
bysort post_tcja treatment_ind: ///
    sum schappy scstress scpain sctired meaning [aw = awbwt] if financial_act == 1

*--- Regression: well-being outcomes during financial activities ---
local first = 1
foreach outcome in schappy scstress scpain sctired meaning {
    local lab = cond("`outcome'" == "schappy",  "Happiness", ///
                cond("`outcome'" == "scstress", "Stress (reversed)", ///
                cond("`outcome'" == "scpain",   "Pain",    ///
                cond("`outcome'" == "sctired",  "Tiredness", "Meaning"))))

    reg `outcome' did_ind treatment_ind post_tcja financial_act ///
        c.did_ind#c.financial_act c.treatment_ind#c.financial_act ///
        c.post_tcja#c.financial_act ///
        duration $controls i.year i.statefip ///
        spouse-non_household_members ///
        [pw = awbwt], robust cluster(statefip)

    local action = cond(`first' == 1, "replace", "append")
    outreg2 using "Results/Table5_WellBeing.xls", ///
        ctitle("`lab'") ///
        keep(did_ind treatment_ind post_tcja financial_act ///
             c.did_ind#c.financial_act c.post_tcja#c.financial_act ///
             duration $controls) ///
        addtext("Controls","Yes","State FE","Yes","Year FE","Yes") ///
        bdec(3) se `action'
    local first = 0
}

*--- Well-being for financial activities only ---
preserve
keep if financial_act == 1
local first = 1
foreach outcome in schappy scstress sctired {
    local lab = cond("`outcome'" == "schappy",  "Happiness", ///
                cond("`outcome'" == "scstress", "Stress", "Tiredness"))
    reg `outcome' did_ind treatment_ind post_tcja duration ///
        $controls i.year i.statefip ///
        [pw = awbwt], robust cluster(statefip)
    local action = cond(`first' == 1, "replace", "append")
    outreg2 using "Results/Table5_WellBeing_FinancialOnly.xls", ///
        ctitle("`lab' (Fin. Only)") ///
        keep(did_ind treatment_ind post_tcja duration $controls) ///
        addtext("Controls","Yes","State FE","Yes","Year FE","Yes") ///
        bdec(3) se `action'
    local first = 0
}
restore



********************************************************************************
** PART VI - HETEROGENEITY BY EDUCATION AND SALT EXPOSURE (Table 6)
********************************************************************************
**  Note: income tercile splits removed - they are collinear with i.famincome
**  controls (treatment_ind is itself defined by famincome categories).
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- Initialize: first regression uses 'replace', subsequent use 'append' ---
local first = 1

*--- By education ---
foreach educ_grp in 1 2 3 {
    local educ_lbl = cond(`educ_grp'==1, "Less than HS", ///
                     cond(`educ_grp'==2, "Some College", "College+"))
    preserve
    keep if educ_`educ_grp' == 1
    reg financial did_ind treatment_ind post_tcja $controls_noinc ///
        i.year i.statefip [pw = wt06], robust cluster(statefip)
    local action = cond(`first' == 1, "replace", "append")
    outreg2 using "Results/Table6_Heterogeneity.xls", ///
        ctitle("Educ: `educ_lbl'") ///
        keep(did_ind treatment_ind post_tcja $controls_noinc) ///
        addtext("Subgroup","Education","Group","`educ_lbl'") bdec(3) se `action'
    local first = 0
    restore
}

*--- By state SALT exposure (high vs low pre-TCJA itemization quintile) ---
foreach salt in 0 1 {
    local lbl = cond(`salt' == 1, "High SALT (Q5)", "Low/Mid SALT (Q1-Q4)")
    preserve
    keep if high_salt_state == `salt'
    reg financial did_ind treatment_ind post_tcja $controls ///
        i.year i.statefip [pw = wt06], robust cluster(statefip)
    outreg2 using "Results/Table6_Heterogeneity.xls", ///
        ctitle("`lbl'") ///
        keep(did_ind treatment_ind post_tcja $controls) ///
        addtext("Subgroup","SALT exposure","Group","`lbl'") bdec(3) se append
    restore
}

*--- By gender (cross-reference with Table 4 but using same setup) ---
foreach m in 0 1 {
    local lbl = cond(`m' == 1, "Men", "Women")
    preserve
    keep if male == `m'
    reg financial did_ind treatment_ind post_tcja $controls ///
        i.year i.statefip [pw = wt06], robust cluster(statefip)
    outreg2 using "Results/Table6_Heterogeneity.xls", ///
        ctitle("Gender: `lbl'") ///
        keep(did_ind treatment_ind post_tcja $controls) ///
        addtext("Subgroup","Gender","Group","`lbl'") bdec(3) se append
    restore
}


********************************************************************************
** PART VII - CONTINUOUS DiD: STATE TREATMENT INTENSITY (Table 7)
********************************************************************************
**  Identification: differential effect of TCJA on time use, by states' average
**  pre-TCJA itemization rate (treat_intensity).
**
**  Specification notes:
**   - treat_intensity is constant within state, so it is absorbed by i.statefip
**     and must be EXCLUDED from RHS (otherwise Stata drops did_state for collinearity)
**   - post_tcja is constant within year, so it is absorbed by i.year and must
**     also be excluded from RHS
**   - did_state = treat_intensity x post_tcja  varies by state x year and is
**     therefore identified from the state-by-year cells
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- Column 1: state-level continuous DiD ---
*   did_state alone, with state FE absorbing treat_intensity
*   and year FE absorbing post_tcja.
reg financial did_state $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table7_Continuous_DiD.xls", ///
    ctitle("(1) State Intensity x Post") ///
    keep(did_state $controls) ///
    addtext("State FE","Yes","Year FE","Yes","Spec","State-level continuous") ///
    bdec(3) se replace

*--- Column 2: state continuous DiD + individual treatment interaction ---
*   Triple interaction treat_intensity x treatment_ind x post_tcja
*   Build auxiliary lower-order interactions that are NOT absorbed by FEs.
generate ti_x_treat = treat_intensity * treatment_ind        // varies state x ind
generate did_triple = treat_intensity * treatment_ind * post_tcja
label variable ti_x_treat  "Treat_intensity x Treatment_ind"
label variable did_triple  "Triple: Treat_intensity x Treatment_ind x Post"

reg financial did_triple did_state did_ind ti_x_treat treatment_ind ///
    $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table7_Continuous_DiD.xls", ///
    ctitle("(2) Triple Interaction") ///
    keep(did_triple did_state did_ind ti_x_treat treatment_ind $controls) ///
    addtext("State FE","Yes","Year FE","Yes","Spec","Triple interaction") ///
    bdec(3) se append

*--- Column 3: alternative - by SALT-state quintile (discrete) ---
*   For comparison, use high_salt_state (Q5) instead of continuous treat_intensity
generate did_salt_treat = high_salt_state * treatment_ind * post_tcja
label variable did_salt_treat "High SALT state x Treatment_ind x Post"

reg financial did_salt_treat did_salt did_ind c.high_salt_state#c.treatment_ind ///
    treatment_ind $controls i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table7_Continuous_DiD.xls", ///
    ctitle("(3) High-SALT x Treat x Post") ///
    keep(did_salt_treat did_salt did_ind treatment_ind $controls) ///
    addtext("State FE","Yes","Year FE","Yes","Spec","Discrete SALT interaction") ///
    bdec(3) se append



********************************************************************************
** PART VIII - ROBUSTNESS CHECKS (Table 8)
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear


*--- R1: Placebo test - fake reform year = 2015 ---
preserve
keep if year <= 2017    // use only pre-reform years
generate post_fake    = (year >= 2015)
generate did_fake     = treatment_ind * post_fake
reg financial did_fake treatment_ind post_fake $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table8_Robustness.xls", ///
    ctitle("(R1) Placebo Reform 2015") ///
    keep(did_fake treatment_ind post_fake) ///
    addtext("Note","Placebo: fake reform year = 2015") bdec(3) se replace
restore

*--- R2: Exclude high-income (famincome 16) from treatment ---
preserve
keep if famincome <= 15 | control_group == 1
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table8_Robustness.xls", ///
    ctitle("(R2) Excl. famincome=16") ///
    keep(did_ind treatment_ind post_tcja) ///
    addtext("Note","Excludes famincome=16 from sample") bdec(3) se append
restore

*--- R3: No-income-tax states (control for alternative channels) ---
reg financial did_ind treatment_ind post_tcja no_income_tax ///
    c.did_ind#c.no_income_tax $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table8_Robustness.xls", ///
    ctitle("(R3) No-Tax State Control") ///
    keep(did_ind treatment_ind post_tcja no_income_tax c.did_ind#c.no_income_tax) ///
    addtext("Note","Interacts DiD with no-income-tax state indicator") bdec(3) se append

*--- R4: Poisson quasi-MLE for skewed count outcome (minutes) ---
*   Financial time is right-skewed; Poisson QMLE is consistent for non-negative
*   outcomes regardless of the true distribution (Gourieroux et al. 1984).
poisson financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], vce(cluster statefip)

*--- R5: Log(financial + 1) ---
generate log_financial = log(financial + 1)
reg log_financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table8_Robustness.xls", ///
    ctitle("(R5) Log(Financial+1)") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Outcome","log(financial + 1)") bdec(3) se append


********************************************************************************
** PART VIII-B [NEW] - MAGNITUDE PLAUSIBILITY CHECK & MINIMUM DETECTABLE EFFECT
********************************************************************************
**  Reviewer #1 (pt.4): asks the authors to confront the magnitude of the
**  estimates against outside benchmarks (IRS Tax Burden Survey ~13h/year).
**  Reviewer #2: asks for an explicit statistical-power discussion instead
**  of calling the null "precise" based only on % of the control mean.
**  This block computes both diagnostics from the data actually used in the
**  regressions, rather than the reviewer's own back-of-envelope numbers.
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- (a) Minimum detectable effect (MDE), main DiD, 80% power / 5% size ---
*   Standard formula: MDE = (z_{alpha/2} + z_{power}) * SE(beta)
qui reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
local se_did = _se[did_ind]
local mde = (1.96 + 0.84) * `se_did'
qui sum financial [aw = wt06] if control_group == 1 & post_tcja == 0
local premean = r(mean)
di ""
di "=================================================================="
di "  MINIMUM DETECTABLE EFFECT - main DiD (80% power, 5% size)"
di "=================================================================="
di "  SE(did_ind)                          = " %6.3f `se_did' " min/day"
di "  MDE                                  = " %6.3f `mde' " min/day"
di "  Pre-period control-group mean        = " %6.3f `premean' " min/day"
di "  MDE as % of pre-period control mean  = " %5.1f (`mde'/`premean')*100 "%"
di "  --> report this alongside the point estimate instead of relying on"
di "      '% of control mean' alone to argue the null is 'precise' (Rev#2)."
di "=================================================================="
di ""

*--- (b) Implied ATT on switchers, college-educated subgroup ---
*   Attempts a data-driven itemization-decline gap using delta_1718 (state
*   pp change in itemization 2017->2018, computed in Sample_Creation_TCJA.do
*   STEP 4), then falls back to Reviewer #1's own ~30pp assumption
*   (from Tax Foundation 2019 figures) if the state-level proxy turns out
*   to be too close to zero to use as a denominator. delta_1718 is a
*   STATE-level average across ALL income brackets, so unless treated and
*   control households are concentrated in very different states, it will
*   NOT differ much between the two groups by construction - it is not a
*   good proxy for the income-specific itemization decline this
*   calculation needs. A MIN_GAP safety threshold prevents a
*   near-zero-denominator blow-up (this happened in an earlier run: a
*   0.0pp gap produced a nonsensical -38,433 min/day implied ATT).
local MIN_GAP = 1  // pp; below this, treat the state-level proxy as uninformative

qui sum delta_1718 [aw = wt06] if treatment_ind == 1
local switch_treated = abs(r(mean))
qui sum delta_1718 [aw = wt06] if control_group == 1
local switch_control = abs(r(mean))
local switch_gap = `switch_treated' - `switch_control'

qui reg financial did_ind treatment_ind post_tcja $controls_noinc ///
    i.year i.statefip if educ_3 == 1 [pw = wt06], robust cluster(statefip)
local beta_college = _b[did_ind]

di "=================================================================="
di "  MAGNITUDE PLAUSIBILITY CHECK - college-educated subgroup"
di "=================================================================="
di "  Mean |delta_1718| (pp itemization decline), treated group  = " %5.2f `switch_treated'
di "  Mean |delta_1718| (pp itemization decline), control group  = " %5.2f `switch_control'
di "  Implied itemization-decline GAP (treated - control), pp    = " %5.2f `switch_gap'
di "  ITT coefficient, college-educated (did_ind)                = " %6.3f `beta_college' " min/day"
if `switch_gap' > `MIN_GAP' {
    local att_college = `beta_college' / (`switch_gap'/100)
    local hrs_college = `att_college' * 365 / 60
    di "  Implied ATT on switchers (state-level proxy)                = " %7.1f `att_college' " min/day"
    di "  ... equivalent to                                            = " %6.1f `hrs_college' " hours/year"
    di "  BENCHMARK: IRS Tax Burden Survey ~= 13 hours/year for the"
    di "  average filer's ENTIRE return (Reviewer #1, point 4)."
    if abs(`hrs_college') > 13 {
        di "  FLAG: implied ATT exceeds the total-filing-time benchmark -"
        di "  discuss explicitly in the paper (compositional story, measurement"
        di "  error, or genuine outlier subgroup) rather than leaving it implicit."
    }
}
else {
    di "  NOTE: the state-level delta_1718 gap (" %4.2f `switch_gap' "pp) is below the"
    di "  " %2.0f `MIN_GAP' "pp threshold - as expected, since delta_1718 is a STATE"
    di "  average across ALL income brackets and cannot meaningfully separate"
    di "  treated vs control households within the same state. Do NOT use it"
    di "  to defend the college+ magnitude. Falling back to Reviewer #1's own"
    di "  ~30pp assumption (Tax Foundation 2019) for a sensitivity calculation:"
    local att_college_fallback = `beta_college' / 0.30
    local hrs_college_fallback = `att_college_fallback' * 365 / 60
    di "  Implied ATT using an assumed 30pp gap                       = " %7.1f `att_college_fallback' " min/day"
    di "  ... equivalent to                                            = " %6.1f `hrs_college_fallback' " hours/year"
    di "  BENCHMARK: IRS Tax Burden Survey ~= 13 hours/year for the average filer."
    if abs(`hrs_college_fallback') > 13 {
        di "  FLAG: even under the 30pp assumption, implied ATT exceeds the"
        di "  13h/year benchmark - discuss explicitly in the paper rather than"
        di "  leaving it implicit (this is Reviewer #1's own point-4 finding,"
        di "  confirmed on this data)."
    }
    di "  For a real (non-fallback) number, compute the itemization-decline"
    di "  gap from IRS SOI Historic Table 2 BY INCOME BRACKET (not by state) -"
    di "  the state-level file merged here cannot answer this question."
}
di "=================================================================="
di ""


********************************************************************************
** PART IX - FIGURES
********************************************************************************

use "Data/TCJA_Financial_Time.dta", clear

*--- Figure 3: Mean financial time by treatment group over time ---
preserve
collapse (mean) financial [pw = wt06], by(year treatment_ind)

twoway ///
    (connected financial year if treatment_ind == 0, ///
        lpattern(dash) lcolor(navy) lwidth(medthick) ///
        msymbol(O) mcolor(navy) msize(medsmall)) ///
    (connected financial year if treatment_ind == 1, ///
        lpattern(solid) lcolor(maroon) lwidth(medthick) ///
        msymbol(D) mcolor(maroon) msize(medsmall)) ///
    , xline(2017.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
    legend(order(1 "Control: HH income < $35k" 2 "Treated: HH income $50k-$100k") ///
           position(6) rows(1) size(small) region(lwidth(none))) ///
    title("Mean Daily Time in Financial Activities", size(medium)) ///
    subtitle("Treated vs. control households, 2013-2023", size(small)) ///
    xtitle("ATUS Wave Year", size(small)) ///
    ytitle("Mean minutes per day", size(small)) ///
    xlabel(2013(1)2023, angle(45) labsize(small)) ///
    ylabel(, angle(0) format(%4.1f) labsize(small) gmin gmax) ///
    note("Treated group: households with annual income $50k-$100k (likely TCJA itemization 'switchers')." ///
         "Control group: households with income < $35k (rarely itemized in either period)." ///
         "Dashed red line: TCJA effective (Jan 2018). Weighted by ATUS replicate weights." ///
         "Source: ATUS 2013-2023, restricted to employed respondents.", size(vsmall)) ///
    graphregion(color(white) margin(medium)) plotregion(margin(medium)) ///
    scheme(s2color)
graph export "Results/Figure3_FinancialTime_Trends.png", replace width(2400)
restore

*--- Figure 4: Mean financial time by gender and treatment group ---
preserve
collapse (mean) financial [pw = wt06], by(year treatment_ind male)

twoway ///
    (connected financial year if treatment_ind == 1 & male == 0, ///
        lpattern(solid) lcolor(maroon) lwidth(medthick) ///
        msymbol(D) mcolor(maroon) msize(small)) ///
    (connected financial year if treatment_ind == 1 & male == 1, ///
        lpattern(dash)  lcolor(maroon) lwidth(medthick) ///
        msymbol(D) mcolor(maroon*0.6) msize(small)) ///
    (connected financial year if treatment_ind == 0 & male == 0, ///
        lpattern(solid) lcolor(navy) lwidth(medthick) ///
        msymbol(O) mcolor(navy) msize(small)) ///
    (connected financial year if treatment_ind == 0 & male == 1, ///
        lpattern(dash)  lcolor(navy) lwidth(medthick) ///
        msymbol(O) mcolor(navy*0.6) msize(small)) ///
    , xline(2017.5, lpattern(dash) lcolor(cranberry) lwidth(medthick)) ///
    legend(order(1 "Treated - Women" 2 "Treated - Men" ///
                 3 "Control - Women" 4 "Control - Men") ///
           position(6) rows(2) size(small) region(lwidth(none))) ///
    title("Time in Financial Activities by Gender and Treatment Group", size(medium)) ///
    subtitle("Mean daily minutes, 2013-2023", size(small)) ///
    xtitle("ATUS Wave Year", size(small)) ///
    ytitle("Mean minutes per day", size(small)) ///
    xlabel(2013(1)2023, angle(45) labsize(small)) ///
    ylabel(, angle(0) format(%4.1f) labsize(small)) ///
    note("Treated: HH income $50k-$100k. Control: HH income < $35k." ///
         "Dashed red line: TCJA effective (Jan 2018). Weighted by ATUS replicate weights." ///
         "Source: ATUS 2013-2023, restricted to employed respondents.", size(vsmall)) ///
    graphregion(color(white) margin(medium)) plotregion(margin(medium)) ///
    scheme(s2color)
graph export "Results/Figure4_Gender_Trends.png", replace width(2400)
restore


********************************************************************************
** FINAL NOTE
********************************************************************************

di ""
di "=================================================================="
di "  All results exported to Results/ subdirectory."
di ""
di "  Key tables:"
di "    Table2_Main_DiD.xls        - Main DiD estimates (H1); cols (7)-(8) NEW"
di "    Table3_EventStudy.xls      - Parallel trends test (-5/+5 window)"
di "    Table9_TaxSeason_TripleDiD.xls - [NEW] Treat x Post x Tax-season"
di "    Table4_Gender.xls          - Gender heterogeneity (H3)"
di "    Table10_Subgroup_EventStudy.xls - [NEW] Pre-trends: college+, high-SALT"
di "    Table5_WellBeing.xls       - Well-being outcomes (H2)"
di "    Table6_Heterogeneity.xls   - Education, SALT, gender subgroups"
di "    Table7_Continuous_DiD.xls  - State-level treatment intensity"
di "    Table8_Robustness.xls      - Robustness checks"
di ""
di "  Figures (PNG, 2400px wide):"
di "    Figure1_EventStudy.png     - Main event study (vertical, delta minutes)"
di "    Figure2_EventStudy_*.png   - Event study by gender (Men, Women)"
di "    Figure5_EventStudy_CollegePlus.png - [NEW] Event study, college+"
di "    Figure6_EventStudy_HighSALT.png    - [NEW] Event study, high-SALT states"
di "    Figure3_FinancialTime_Trends.png   - Mean trends by treatment group"
di "    Figure4_Gender_Trends.png          - Mean trends by gender x treatment"
di ""
di "  Also check the Stata log for:"
di "    - the 'transition zone' sample diagnostic (from Sample_Creation_TCJA.do)"
di "    - the minimum detectable effect and magnitude plausibility check"
di "      (Part VIII-B above)"
di "=================================================================="

*log close
