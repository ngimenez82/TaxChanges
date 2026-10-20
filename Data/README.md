# Data

The data files are **not distributed** in this repository. To replicate the analysis, place the following files in this folder:

| File | Source | Role |
|---|---|---|
| `ATUS_Clean.dta` | American Time Use Survey (ATUS) microdata, including the Well-Being Module, available from [IPUMS ATUS](https://www.atusdata.org) or the [BLS](https://www.bls.gov/tus/) | Raw input |
| `TCJA_State_Data_DiD.xlsx` | State-level itemization data built from IRS Statistics of Income, Historic Table 2 ([IRS SOI](https://www.irs.gov/statistics/soi-tax-stats-historic-table-2)) | Raw input |

Running `Dofiles/Sample_Creation_TCJA.do` then creates:

- `TCJA_State_Treatment.dta`: state-level treatment intensity
- `TCJA_Financial_Time.dta`: time-use analysis sample
- `TCJA_Financial_WellBeing.dta`: Well-Being Module analysis sample
