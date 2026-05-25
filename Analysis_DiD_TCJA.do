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
*    Part I   - Table 1: Summary statistics
*    Part II  - Table 2: Main DiD (H1: time in financial activities)
*    Part III - Table 3: Event study / parallel trends test (Figure 1)
*    Part IV  - Table 4: DiD by gender (H3) (Figure 2a, 2b)
*    Part V   - Table 5: Well-being DiD (H2)
*    Part VI  - Table 6: Heterogeneity by education, SALT exposure, gender
*    Part VII - Table 7: Continuous DiD (state treatment intensity)
*    Part VIII- Table 8: Robustness checks
*    Part IX  - Figures (Figure 3 trends, Figure 4 by gender)
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
sum financial personal_care housework childcare adult_care market_work study leisure  [aw = wt06]

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


*--- Column 1: Simple DiD, no controls ---
reg financial did_ind treatment_ind post_tcja i.year i.statefip ///
    [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(1) Simple DiD") ///
    keep(did_ind treatment_ind post_tcja) ///
    addtext("Controls","No","State FE","Yes","Year FE","Yes") ///
    bdec(3) se replace

*--- Column 2: With demographics ---
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(2) With Controls") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes") ///
    bdec(3) se append

*--- Column 3: Treatment = $50k-$100k vs. control = <$35k ---
*   (restrict to these two groups for clean comparison)
preserve
keep if treatment_ind == 1 | control_group == 1
reg financial did_ind treatment_ind post_tcja $controls ///
    i.year i.statefip [pw = wt06], robust cluster(statefip)
outreg2 using "Results/Table2_Main_DiD.xls", ///
    ctitle("(3) Clean Comparison") ///
    keep(did_ind treatment_ind post_tcja $controls) ///
    addtext("Controls","Yes","State FE","Yes","Year FE","Yes","Sample","50-100k vs <35k") ///
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
di "    Table2_Main_DiD.xls       - Main DiD estimates (H1)"
di "    Table3_EventStudy.xls     - Parallel trends test (-5/+5 window)"
di "    Table4_Gender.xls         - Gender heterogeneity (H3)"
di "    Table5_WellBeing.xls      - Well-being outcomes (H2)"
di "    Table6_Heterogeneity.xls  - Education, SALT, gender subgroups"
di "    Table7_Continuous_DiD.xls - State-level treatment intensity"
di "    Table8_Robustness.xls     - Robustness checks"
di ""
di "  Figures (PNG, 2400px wide):"
di "    Figure1_EventStudy.png    - Main event study (vertical, Δ minutes)"
di "    Figure2_EventStudy_*.png  - Event study by gender (Men, Women)"
di "    Figure3_FinancialTime_Trends.png - Mean trends by treatment group"
di "    Figure4_Gender_Trends.png        - Mean trends by gender x treatment"
di "=================================================================="

*log close
