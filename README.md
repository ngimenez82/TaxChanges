# TaxChanges
TCJA Financial Complexity and Time Use
Project Overview
This repository contains the data construction and empirical analysis code for the paper:
> **“Causal Effects of Financial Complexity Shocks on Time Use and Emotional Well-Being: Evidence from Tax Policy Changes (TCJA 2017)”**
The project studies how the reduction in tax filing complexity induced by the 2017 U.S. Tax Cuts and Jobs Act (TCJA) affected:
Time spent on financial activities
Household production and labor allocation
Emotional well-being during financial activities
using microdata from the American Time Use Survey (ATUS).
The empirical strategy exploits variation in exposure to the TCJA across:
Income groups (households likely vs unlikely to itemize deductions)
States (variation in pre-TCJA itemization intensity)
through a Difference-in-Differences (DiD) design.
---
Repository Structure
```text
├── Data/
│   ├── ATUS_Clean.dta
│   ├── TCJA_State_Data_DiD.xlsx
│   ├── TCJA_State_Treatment.dta
│   ├── TCJA_Financial_Time.dta
│   └── TCJA_Financial_WellBeing.dta
│
├── Dofiles/
│   ├── Sample_Creation_TCJA.do
│   └── Analysis_DiD_TCJA.do
│
├── Results/
│   ├── Table2_Main_DiD.xls
│   ├── Figures/
│   └── Logs/
│
└── README.md
```
---
Data Sources
1. American Time Use Survey (ATUS)
Main microdata source used for:
Daily time allocation
Demographics
Employment characteristics
Well-being modules (WBM)
Sample periods
Analysis	Years
Time-use analysis	2013–2023
Well-being analysis	2010, 2012, 2013, 2021
---
2. IRS SOI Historic Table 2
Used to construct state-level exposure to TCJA changes in itemization behavior.
Main variables include:
Pre-TCJA itemization rate (2015–2017)
Post-TCJA itemization rate (2018–2022)
Change in itemization after TCJA
State tax exposure
Homeownership rates
---
Identification Strategy
The paper uses a Difference-in-Differences framework.
Treated Households
Households with:
```text
$50k–$100k family income
(famincome 12–14)
```
These households were most likely to switch from itemizing deductions to the standard deduction after TCJA.
---
Control Households
Households with:
```text
Income below $35k
(famincome <= 9)
```
These households rarely itemized deductions before or after TCJA.
---
Post-Treatment Period
```stata
post_tcja = 1 if year >= 2018
```
TCJA became effective on January 1, 2018.
---
Main Variables
Time Use Outcomes
Constructed from ATUS activity codes.
Variable	Description
`financial`	Time in financial management activities
`housework`	Household production
`childcare`	Childcare activities
`adult_care`	Adult care activities
`market_work`	Paid work
`leisure`	Leisure activities
`study`	Educational activities
`personal_care`	Sleep and personal care
---
Treatment Variables
Variable	Description
`treatment_ind`	Middle-income treated households
`treatment_high`	High-income households
`did_ind`	Main DiD interaction
`did_high`	High-income DiD interaction
`did_state`	Continuous state-level treatment intensity
`did_salt`	High-SALT-state exposure interaction
`treatment_proxy`	Treatment × homeownership proxy
`did_proxy`	DiD with homeownership proxy
---
Sample Construction
Time-Use Sample
Generated in:
```stata
do Dofiles/Sample_Creation_TCJA.do
```
Main restrictions
Years: 2013–2023
Exclude workers absent from work
One observation per person-day
Complete diary days only (`total_time == 1440`)
Family income categories ≤ 16
Additional processing
Construction of detailed activity categories
Wage harmonization
State-level treatment merge
Event-study variables
Demographic controls
Final sample size
```text
N = 87,779 person-days
```
---
Well-Being Sample
Uses the ATUS Well-Being Module (WBM).
Available years
```text
2010, 2012, 2013, 2021
```
Main restrictions
WBM-eligible episodes only
Valid well-being scores (0–6)
Complete diary days only
Same employment and income filters as the main sample
Final sample size
```text
N = 97,889 episodes
```
---
Empirical Specifications
Main Difference-in-Differences Model
The baseline specification is:
```math
Y_{ist} = \alpha + \beta (Treatment_i \times Post_t) + \gamma X_{ist} + \delta_s + \lambda_t + \varepsilon_{ist}
```
Where:
`Y_ist` is the outcome variable
`Treatment_i` identifies treated households
`Post_t` indicates the post-TCJA period
`X_ist` is a vector of demographic controls
`δ_s` are state fixed effects
`λ_t` are year fixed effects
Standard errors are clustered at the state level.
---
Event Study Design
Dynamic treatment effects are estimated using an event-study framework.
Event Time Definition
Relative Year	Calendar Year
-5	2013
-4	2014
-3	2015
-2	2016
-1	2017 (omitted baseline)
0	2018
+1	2019
+2	2020
+3	2021
+4	2022
+5	2023
Important note
2020 is omitted from event-study interactions due to COVID-19 confounding effects.
---
Main Results (Current Log Output)
Financial Time
Baseline DiD estimates suggest:
Treated households reduced time spent on financial activities after TCJA.
Estimated treatment effect:
```text
did_ind ≈ -0.95 minutes/day
```
Statistical significance:
```text
p ≈ 0.063
```
This is consistent with the hypothesis that simplifying tax filing reduced financial-management time.
---
Controls Included
Preferred specifications include:
Age and age squared
Gender
Education
Marital status
Race/ethnicity
Household size
Number of children
Age of youngest child
Retirement status
Income fixed effects
Year fixed effects
State fixed effects
---
Output Files
Main Tables
File	Description
`Table2_Main_DiD.xls`	Main DiD estimates
`Table3_EventStudy.xls`	Event-study coefficients
`Table4_Gender.xls`	Gender heterogeneity analysis
`Table5_WellBeing.xls`	Well-being regressions
`Table6_Heterogeneity.xls`	Heterogeneity analyses
`Table7_StateIntensity.xls`	Continuous-treatment DiD
`Table8_Robustness.xls`	Robustness checks
---
Required Stata Packages
Install before running:
```stata
ssc install outreg2
ssc install coefplot
ssc install estout
```
---
Replication Workflow
Step 1 — Create Samples
Run:
```stata
do Dofiles/Sample_Creation_TCJA.do
```
This generates:
```text
Data/TCJA_Financial_Time.dta
Data/TCJA_Financial_WellBeing.dta
```
---
Step 2 — Run Main Analysis
Run:
```stata
do Dofiles/Analysis_DiD_TCJA.do
```
This produces:
Regression tables
Event-study estimates
Figures
Robustness checks
Heterogeneity analyses
---
Methodological Notes
ATUS does not directly report homeownership status.
The analysis therefore constructs a proxy using:
marital status,
presence of children,
and household income.
State-level treatment intensity is based on pre-TCJA itemization rates.
The empirical design assumes:
parallel trends,
stable sample composition,
and no simultaneous differential shocks aside from TCJA.
2020 is partially excluded in event-study specifications to avoid contamination from COVID-related shocks.
---
Suggested Citation
```text
[Author names]

"Causal Effects of Financial Complexity Shocks on Time Use and Emotional Well-Being:
Evidence from Tax Policy Changes (TCJA 2017)"
```
---
Contact
For questions, replication issues, or data access requests, please contact the authors.
