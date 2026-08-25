# TaxChanges

## TCJA Financial Complexity and Time Use

Data construction and empirical analysis code for the paper:

**"Did Tax Simplification Reduce Household Financial Management Burden? Evidence from the Tax Cuts and Jobs Act"**
José Ignacio Giménez-Nadal and José Alberto Molina

### Abstract

We estimate the effect of the 2017 Tax Cuts and Jobs Act (TCJA) on household time devoted to financial management, using the American Time Use Survey (ATUS), 2013–2023. Comparing households earning $50,000–$100,000, likely to stop itemizing after the reform, against a control group earning below $35,000, we find no significant average effect (+0.53 min/day, SE = 0.56). The null survives every check a referee could reasonably demand: a narrower tax- and insurance-specific outcome, a triple-difference test isolating tax-filing season, a pre-COVID sample, and a power analysis detecting effects a fifth the control-group mean. Event studies confirm parallel pre-reform trends. One subgroup effect survives scrutiny: college-educated households show a significant reduction (-1.36 min/day, p = 0.04) passing its own pre-trends test, though the implied effect on likely switchers exceeds IRS compliance-cost benchmarks, a tension we discuss openly. A previously reported high-SALT-state effect fails its pre-trends test and is not treated as causal. Using the ATUS Well-Being Module, we find a decline in happiness during financial management after the reform; since the only post-reform wave (2021) is confounded with pandemic disruption, we treat this as suggestive, not causal. Overall, tax simplification produced, at most, modest time savings, concentrated among the most financially sophisticated households.

## Project Overview

This project studies how the reduction in tax-filing complexity induced by the 2017 U.S. Tax Cuts and Jobs Act (TCJA) affected:

- Time spent on financial activities
- Household production and labor allocation
- Emotional well-being during financial activities

using microdata from the American Time Use Survey (ATUS).

The empirical strategy exploits variation in exposure to the TCJA across:

- Income groups (households likely vs. unlikely to itemize deductions)
- States (variation in pre-TCJA itemization intensity)

through a Difference-in-Differences (DiD) design, complemented by an event-study design and a tax-season triple-difference design.

## Data Sources

### 1. American Time Use Survey (ATUS)

Main microdata source used for:

- Daily time allocation
- Demographics
- Employment characteristics
- Well-Being Module (WBM)

**Sample periods**

| Analysis | Years |
|---|---|
| Time-use analysis | 2013–2023 |
| Well-being analysis | 2010, 2012, 2013, 2021 |

### 2. IRS SOI Historic Table 2

Used to construct state-level exposure to TCJA changes in itemization behavior. Main variables include:

- Pre-TCJA itemization rate (2015–2017)
- Post-TCJA itemization rate (2018–2022)
- Change in itemization after TCJA
- State tax exposure (SALT)
- Homeownership rates

## Identification Strategy

The paper uses a Difference-in-Differences framework.

**Treated households** — family income $50k–$100k (`famincome` 12–14). These households were most likely to switch from itemizing deductions to the standard deduction after TCJA.

**Control households** — income below $35k (`famincome` <= 9). These households rarely itemized deductions before or after TCJA.

**Post-treatment period**

```
post_tcja = 1 if year >= 2018
```

TCJA became effective on January 1, 2018.

**Preferred comparison.** The headline specification compares the treated group only against this clean, low-itemization control group (N = 53,954), not against all non-treated households pooled together (N = 87,779, which also includes the transition-income zone and high-income households). An early working version of the paper used the pooled comparison and is retained in the code for transparency, but it is **not** the preferred specification — see Methodological Notes.

## Main Variables

### Time Use Outcomes

Constructed from ATUS activity codes.

| Variable | Description |
|---|---|
| `financial` | Time in financial management activities |
| `housework` | Household production |
| `childcare` | Childcare activities |
| `adult_care` | Adult care activities |
| `market_work` | Paid work |
| `leisure` | Leisure activities |
| `study` | Educational activities |
| `personal_care` | Sleep and personal care |

The narrow outcome used in several robustness checks restricts `financial` to tax- and insurance-specific ATUS activity codes only.

### Treatment and Design Variables

| Variable | Description |
|---|---|
| `treatment_ind` | Middle-income treated households |
| `treatment_high` | High-income households |
| `did_ind` | Main DiD interaction (treatment × post) |
| `did_high` | High-income DiD interaction |
| `did_state` | Continuous state-level treatment intensity |
| `did_salt` / `did_salt_treat` | High-SALT-state exposure interaction |
| `treatment_proxy` / `did_proxy` | Treatment × homeownership proxy |
| `tax_season` / `treat_x_season` / `did_x_season` / `did_triple` | Tax-filing-season (Jan–Apr) triple-difference terms |
| `did_fake` / `post_fake` | Placebo reform (fake treatment year 2015) |
| `no_income_tax` | No-income-tax-state indicator (robustness) |
| `financial_act` | Episode-level indicator for a financial-management activity (Well-Being Module) |

## Sample Construction

### Time-Use Sample

Generated in:

```
do Dofiles/Sample_Creation_TCJA.do
```

**Main restrictions**

- Years: 2013–2023
- Exclude workers absent from work
- One observation per person-day
- Complete diary days only (`total_time == 1440`)
- Family income categories ≤ 16

**Additional processing**

- Construction of detailed activity categories (including the narrow tax/insurance outcome)
- Wage harmonization
- State-level treatment merge
- Event-study and tax-season variables
- Demographic controls

**Final sample size:** N = 87,779 person-days (N = 53,954 in the preferred clean treatment-vs-control comparison)

### Well-Being Sample

Uses the ATUS Well-Being Module (WBM).

**Available years:** 2010, 2012, 2013, 2021

**Main restrictions**

- WBM-eligible episodes only
- Valid well-being scores (0–6)
- Complete diary days only
- Same employment and income filters as the main sample

**Final sample size:** N = 97,889 episodes (N = 1,576 for the financial-activity-only subsample)

**Caveat.** The Well-Being Module was fielded only in 2012, 2013, and 2021, so its only post-reform wave (2021) is confounded with pandemic-era disruption. Well-being results are reported as suggestive, not causal.

## Empirical Specifications

### Main Difference-in-Differences Model

The baseline specification is:

Y_ist = α + β(Treatment_i × Post_t) + γX_ist + δ_s + λ_t + ε_ist

Where:

- `Y_ist` is the outcome variable
- `Treatment_i` identifies treated households
- `Post_t` indicates the post-TCJA period
- `X_ist` is a vector of demographic controls
- `δ_s` are state fixed effects
- `λ_t` are year fixed effects

Standard errors are clustered at the state level (robust throughout).

### Event Study Design

Dynamic treatment effects are estimated using an event-study framework.

| Relative Year | Calendar Year |
|---|---|
| -5 | 2013 |
| -4 | 2014 |
| -3 | 2015 |
| -2 | 2016 |
| -1 | 2017 (omitted baseline) |
| 0 | 2018 |
| +1 | 2019 |
| +2 | 2020 |
| +3 | 2021 |
| +4 | 2022 |
| +5 | 2023 |

**Important note:** 2020 is omitted from event-study interactions due to COVID-19 confounding effects, and a separate pre-COVID-only sample (2013–2019) is used as a robustness check.

### Tax-Season Triple-Difference

Since the standard-deduction change should mechanically affect time use only during tax-filing season, a triple-difference specification interacts the DiD term with a January–April tax-season indicator, isolating whether any effect is concentrated in the months when itemization-related record-keeping actually occurs.

## Main Results

### Headline effect: a precisely estimated null

In the preferred specification (clean treatment vs. true control, N = 53,954), the TCJA is associated with a statistically insignificant **+0.53 minutes/day** change in financial-management time (SE = 0.56). This is the paper's central estimate; an earlier working specification that pooled all non-treated households into a single comparison group produced a different, larger point estimate, but that comparison is not the preferred one (see Methodological Notes).

A power analysis shows the design is well powered: at conventional 80% power, the minimum detectable effect is well within the range needed to distinguish a meaningful reduction in financial-management time from noise, roughly a fifth of the control-group mean.

### Robustness checks

| Check | Result |
|---|---|
| Narrower outcome (tax/insurance activities only, preferred sample) | Null (-0.16, SE = 0.48) |
| Pre-COVID-only sample (2013–2019) | Null (-0.88, SE = 0.74) |
| Tax-season triple-difference, broad outcome | Null (≈ -0.23, SE ≈ 1.24) |
| Tax-season triple-difference, narrow outcome | Null (≈ -0.47, SE ≈ 1.01) |
| Placebo reform (fake treatment year 2015) | Null (-0.53, SE = 0.76) |
| Log(financial + 1) specification | Null |
| Excluding top income category | Null (-0.04, SE = 0.47) |
| Event-study pre-trends (2013–2016 vs. 2017) | No significant pre-trends |

### Heterogeneity

- **College-educated households** show a statistically significant reduction of **-1.36 min/day** (p ≈ 0.04). This effect passes its own event-study pre-trends test. However, the implied effect on likely "switcher" households is larger than IRS compliance-cost benchmarks make plausible — a tension discussed openly in the paper rather than resolved artificially.
- **High-SALT states** show a similarly sized negative point estimate, but this subgroup **fails its own pre-trends test** (significant, rising pre-reform gaps between treated and control households) and is therefore **not treated as causal evidence**.
- **Gender:** the effect is negative and marginally significant for men (-1.19, p < 0.1) and null for women; the pooled gender interaction is only marginally significant.
- **State tax-exposure intensity** (continuous SALT-based treatment) and the **triple-interaction** specification do not show significant effects.

### Well-being

Using the Well-Being Module, happiness during financial-management activities specifically declines after the reform (interaction coefficient -0.47, p < 0.05), even though overall reported well-being is not significantly affected. Because the only post-reform wave available (2021) coincides with pandemic-era disruption, this result is reported as suggestive rather than causally identified.

### Overall interpretation

Tax simplification produced, at most, modest average time savings in household financial management, concentrated among the most financially sophisticated households (the college-educated subgroup), with no detectable average effect across the broader treated population.

## Output Files

### Main Tables

| File | Description |
|---|---|
| `Table1_SumStats_TCJA.log` | Summary statistics |
| `Table2_Main_DiD.xls` | Main DiD estimates (multiple comparison groups and samples) |
| `Table3_EventStudy.xls` | Event-study coefficients, full sample |
| `Table4_Gender.xls` | Gender heterogeneity analysis |
| `Table5_WellBeing.xls` / `Table5_WellBeing_FinancialOnly.xls` | Well-being regressions (full and financial-activity-only) |
| `Table6_Heterogeneity.xls` | Heterogeneity by education and SALT exposure |
| `Table7_Continuous_DiD.xls` | Continuous state-treatment-intensity and triple-interaction DiD |
| `Table8_Robustness.xls` | Robustness checks (placebo, sample exclusions, no-income-tax states, log outcome) |
| `Table9_TaxSeason_TripleDiD.xls` | Tax-season triple-difference design |
| `Table10_Subgroup_EventStudy.xls` | Pre-trends event studies for the college-educated and high-SALT subgroups |

### Figures

| File | Description |
|---|---|
| `Figure1_EventStudy.png` | Main event-study coefficients |
| `Figure2_EventStudy_Men.png` / `Figure2_EventStudy_Women.png` | Event study by gender |
| `Figure3_FinancialTime_Trends.png` | Raw financial-management time trends |
| `Figure4_Gender_Trends.png` | Raw trends by gender |
| `Figure5_EventStudy_CollegePlus.png` | Pre-trends event study, college-educated subgroup |
| `Figure6_EventStudy_HighSALT.png` | Pre-trends event study, high-SALT-state subgroup |

## Required Stata Packages

Install before running:

```
ssc install outreg2
ssc install coefplot
ssc install estout
```

## Replication Workflow

**Step 1 — Create Samples**

```
do Dofiles/Sample_Creation_TCJA.do
```

This generates:

```
Data/TCJA_Financial_Time.dta
Data/TCJA_Financial_WellBeing.dta
```

**Step 2 — Run Main Analysis**

```
do Dofiles/Analysis_DiD_TCJA.do
```

This produces: regression tables, event-study estimates (including the subgroup pre-trends tests), the tax-season triple-difference results, figures, robustness checks, and heterogeneity analyses.

## Methodological Notes

- ATUS does not directly report homeownership status. The analysis therefore constructs a proxy using marital status, presence of children, and household income.
- State-level treatment intensity is based on pre-TCJA itemization rates.
- The empirical design assumes parallel trends, stable sample composition, and no simultaneous differential shocks aside from TCJA. Event-study pre-trends tests are reported for the main sample and for each heterogeneous subgroup discussed causally.
- 2020 is excluded from event-study specifications, and a pre-COVID-only sample (2013–2019) is reported as a robustness check, to avoid contamination from COVID-related shocks.
- **Preferred comparison group.** The paper's headline and robustness results compare the treated group only against the clean, low-itemization control group (income below $35k), not against all non-treated households pooled together. An earlier pooled-comparison specification is retained in the code and output for transparency but is superseded by the clean comparison throughout the paper.
- A previously reported heterogeneous effect for high-SALT states does not pass its own pre-trends test and is excluded from the paper's causal claims; it is reported here only as part of the full set of estimated specifications.

## Suggested Citation

```
Giménez-Nadal, J.I., and J.A. Molina. "Did Tax Simplification Reduce Household
Financial Management Burden? Evidence from the Tax Cuts and Jobs Act"
```

