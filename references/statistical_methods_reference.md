# Comprehensive Biostatistics Reference

> A method-by-method guide structured for top-tier biomedical journal review.
> Aligned with STROBE, CONSORT, STARD, and TRIPOD standards.

---

## 1. Variable Classification & Descriptive Statistics

### 1.1 Variable Types

| Type | Examples | Description Format | Central Tendency |
|:-----|:---------|:-------------------|:-----------------|
| Continuous (normal) | Age, height, log-biomarker | Mean ± SD | Mean |
| Continuous (skewed) | Cost, length of stay, antibody titer | Median (Q1–Q3) | Median |
| Binary | Sex (M/F), outcome (event/no event) | n (%) | Proportion |
| Nominal | Race, blood type, hospital | n (%) | Mode |
| Ordinal | Cancer stage (I–IV), pain score (0–10) | n (%) or Median (IQR) | Median |
| Count | Number of hospitalizations | Median (IQR) or Mean ± SD | Median/Mean |
| Time-to-event | Survival time, time-to-recurrence | Median (KM estimate) | Median survival |

### 1.2 Rule of Thumb for Display

- **Normal**: `Mean ± SD` — NOT `Mean ± SE` (SE is for inference, not description)
- **Skewed**: `Median (Q1–Q3)` — NOT `Mean ± SD`
- **Highly skewed**: Also consider log-transformation or geometric mean
- **Journals' preference**: Lancet & BMJ explicitly require SD (not SE) for descriptive statistics

---

## 2. Assumption Checking

### 2.1 Normality Tests

| Test | Best For | Strengths | Limitations |
|:-----|:---------|:----------|:------------|
| Shapiro-Wilk | n < 5000 | Most powerful for small samples | Computationally heavy for large n |
| Kolmogorov-Smirnov (Lilliefors) | n ≥ 5000 | Widely available | Lower power than SW |
| Anderson-Darling | General | Better at tail detection | Less common in medical stats |
| D'Agostino-Pearson | General | Combines skewness + kurtosis | Requires large n |
| Q-Q plot | All n | Visual assessment, detects outliers | Subjective |

> **NEJM reviewer note**: In large studies (n > 5000), normality tests will almost always be "significant" due to trivial deviations. Use visual inspection of histograms/Q-Q plots AND skewness/kurtosis (|value| < 2 acceptable).

### 2.2 Homogeneity of Variance

| Test | Usage | Note |
|:-----|:------|:-----|
| F-test of variances | Two groups only | Sensitive to non-normality |
| Levene's test | ≥2 groups | Robust to non-normality |
| Brown-Forsythe | ≥2 groups | More robust than Levene (uses median) |
| Bartlett's test | ≥2 groups | Very sensitive to non-normality |

### 2.3 Proportional Hazards Assumption (Cox)

- **Schoenfeld residuals test**: `cox.zph(model)`
  - P > 0.05: OK
  - P ≤ 0.05: Violation — consider:
    - Stratified Cox model
    - Time-dependent covariates
    - Extended Cox model with interactions
    - Parametric survival models (Weibull, log-normal)
- **Graphical**: log(-log(survival)) curves should be parallel

### 2.4 Linearity Assumption (Logistic/Linear)

- Check using **partial residual plots**
- If violated: use RCS, restricted cubic splines, or fractional polynomials
- **Box-Tidwell test** for logistic regression

### 2.5 Multicollinearity

| Measure | Threshold | Action |
|:--------|:----------|:-------|
| VIF | > 5 (moderate), > 10 (severe) | Remove or combine correlated variables |
| Correlation matrix | |r| > 0.7 | Consider removing one variable |
| Condition index | > 30 | Serious collinearity |

---

## 3. Univariable Methods — Detailed

### 3.1 Two Groups Comparison

| Situation | Test | Test Statistic | Assumptions | Reporting |
|:----------|:-----|:---------------|:------------|:----------|
| Independent, normal, equal var | Student's t-test | t (Welch df) | Normality, equality of variance | t(df) = x.xx, P = x.xxx |
| Independent, normal, unequal var | Welch's t-test | t (Satterthwaite df) | Normality | t(df) = x.xx, P = x.xxx |
| Independent, non-normal | Wilcoxon rank-sum (Mann-Whitney U) | W or U | Same distribution shape | W = xxxx, P = x.xxx |
| Paired, normal | Paired t-test | t | Normality of differences | t(df) = x.xx, P = x.xxx |
| Paired, non-normal | Wilcoxon signed-rank | V | Symmetric differences | V = xxx, P = x.xxx |
| Binary outcome | χ² test | χ² | All expected ≥ 5 | χ²(df) = x.xx, P = x.xxx |
| Binary, small expected < 5 | Fisher's exact | — | Fixed margins | P = x.xxx |
| Paired binary | McNemar's test | χ² | Discordant pairs ≥ 10 | χ²(1) = x.xx, P = x.xxx |
| Ordinal (2 groups) | Cochran-Mantel-Haenszel | χ² | — | χ² = x.xx, P = x.xxx |

### 3.2 Multi-group Comparison

| Situation | Test | Post-hoc | Post-hoc Adjustment |
|:----------|:-----|:---------|:--------------------|
| Independent, normal, equal var | One-way ANOVA | Tukey HSD | Family-wise error rate |
| Independent, normal, unequal var | Welch's ANOVA | Games-Howell | Family-wise error rate |
| Independent, non-normal | Kruskal-Wallis | Dunn's test | Bonferroni or Holm |
| Repeated measures, normal | Repeated measures ANOVA | Paired t with correction | Bonferroni |
| Repeated measures, non-normal | Friedman test | Conover's test | Bonferroni |
| Categorical (multi-group) | χ² test | Pairwise χ² + Bonferroni | Bonferroni |

### 3.3 Correlation

| Method | Variable types | Coefficient | Test |
|:-------|:---------------|:------------|:-----|
| Pearson r | Both continuous, linear | r (−1 to +1) | t-test for r ≠ 0 |
| Spearman ρ | Both continuous/ordinal | ρ (−1 to +1) | Approximation to t |
| Kendall τ-b | Both ordinal or small n | τ (−1 to +1) | Exact test |
| Point-biserial | Binary + continuous | r_{pb} | Equivalent to t-test |
| Phi coefficient | Both binary | φ | Related to χ² |

---

## 4. Multivariable Methods — Detailed

### 4.1 Linear Regression

```r
model <- lm(outcome ~ predictor1 + predictor2 + predictor3, data = df)
summary(model)
```

**Diagnostics:**
| Check | Method | Criterion |
|:------|:-------|:----------|
| Residual normality | Shapiro-Wilk on residuals | P > 0.05 |
| Homoscedasticity | Breusch-Pagan test | P > 0.05 |
| Independence | Durbin-Watson test | Stat ≈ 2 |
| Influential points | Cook's distance | < 1 (or < 4/n) |
| Multicollinearity | VIF | VIF < 5 |

**Reporting**: β-coefficient (95% CI), standardized β, P-value, R², adjusted R²

### 4.2 Logistic Regression

```r
model <- glm(outcome ~ predictor1 + predictor2, family = binomial, data = df)
```

**Assumptions:**
1. Binary outcome
2. Independence of observations
3. Linearity of log-odds (Box-Tidwell test)
4. No multicollinearity

**Model performance:**
- **Discrimination**: AUC-ROC (c-statistic), Somers' D
- **Calibration**: Hosmer-Lemeshow test (P > 0.05 = good fit)
- **Overall**: Nagelkerke R², AIC, BIC

**Reporting**: aOR (95% CI), P-value, AUC (95% CI), HL test P-value

> **Lancet standard**: Report the c-statistic (AUC) with 95% CI. Do NOT rely solely on the Hosmer-Lemeshow test — it can be misleading in large samples.

### 4.3 Cox Proportional Hazards Regression

```r
library(survival)
model <- coxph(Surv(time, status) ~ predictor1 + predictor2, data = df)
```

**Assumptions:**
1. Proportional hazards (Schoenfeld test)
2. Linearity of continuous covariates
3. No excessive influential observations (dfbeta)

**Reporting**: HR (95% CI), P-value, concordance (c-index)

**Key Additional Analyses:**
- **Kaplan-Meier curves** with number-at-risk table
- **Log-rank test** for group comparison
- **Restricted mean survival time (RMST)** if PH violated
- **Landmark analysis** for time-dependent covariates

### 4.4 Ordinal Logistic Regression

```r
library(MASS)
model <- polr(outcome ~ predictor1 + predictor2, data = df, Hess = TRUE)
```

**Assumption**: Proportional odds (Brant test)
- **If violated**: Partial proportional odds model (VGAM package), multinomial logistic, or separate binary logistic models

### 4.5 Poisson / Negative Binomial Regression

| Model | When | Dispersion (φ) |
|:------|:-----|:---------------|
| Poisson | Mean = Variance | φ = 1 |
| Quasi-Poisson | Overdispersion, small | φ > 1, SE corrected |
| Negative binomial | Overdispersion, large | φ > 1, extra parameter |

### 4.6 Longitudinal / Repeated Measures

```r
library(lme4)
model <- lmer(outcome ~ time * group + (1 | subject), data = df)
# Or for binary outcomes:
model <- glmer(outcome ~ time * group + (1 | subject), family = binomial, data = df)
```

**Covariance structures:** Unstructured, AR(1), Compound Symmetry, Toeplitz
**Methods:** GEE (population-averaged), Mixed effects (subject-specific)

---

## 5. Survival Analysis — Extended

| Method | When | Key Output | Note |
|:-------|:-----|:-----------|:-----|
| Kaplan-Meier | Descriptive survival | Survival curve, median survival | Include at-risk table |
| Log-rank test | Compare groups (unadjusted) | χ² statistic | Test of equality |
| Cox PH | Multivariable survival | HR (95% CI) | PH assumption needed |
| Stratified Cox | PH violated for some variables | HR (95% CI) | Stratify on violators |
| Time-dependent Cox | Time-varying covariates | HR (95% CI) | Extended Cox model |
| Competing risks (cause-specific) | Multiple event types | CSHR | Etiologic question |
| Competing risks (sub-distribution) | Prognostic question | SHR (Fine-Gray) | Cumulative incidence |
| Landmark analysis | Time-dependent treatment | HR at landmark time | Avoid immortal time bias |
| Restricted mean survival time (RMST) | PH violated | RMST difference | No PH assumption needed |

---

## 6. Causal Inference Methods

### 6.1 DAG-Based Confounder Selection

- **Confounder**: Causes both exposure and outcome → ADJUST
- **Mediator**: On the causal path → DO NOT ADJUST (over-adjustment bias)
- **Collider**: Caused by both → DO NOT ADJUST (collider bias / Berkson's paradox)
- **Instrumental variable**: Causes exposure, affects outcome only through exposure → Not a confounder

### 6.2 Propensity Score Methods

| Method | Description | Advantage | Disadvantage |
|:-------|:------------|:----------|:-------------|
| 1:1 PSM | Nearest neighbor matching | Simple, intuitive | Data loss |
| 1:k PSM | 1:k matching | More data retained | Bias from poor matches |
| IPTW | Inverse probability weighting | All data retained | Extreme weights issue |
| Stratification | Stratify by PS quintiles | Simple | Residual confounding |
| Covariate adjustment | PS as covariate | Data retained | Model dependence |

**Love plot**: Show standardized mean differences before and after matching.

### 6.3 Instrumental Variable Analysis

**Requirements:**
1. IV → Exposure (relevance)
2. IV → Outcome only through exposure (exclusion restriction)
3. IV not sharing causes with outcome (independence)

**Methods:** Two-stage least squares (2SLS), two-stage predictor substitution

### 6.4 Mediation Analysis

**Mediation types:**
- **Complete**: Direct effect → 0 after adding mediator
- **Partial**: Direct effect reduced but still significant
- **Competing mediation** (indirect effects of opposite signs)

**Reporting**: ACME (average causal mediation effect), ADE (average direct effect), proportion mediated

### 6.5 E-value

- E-value: minimum strength of association an unmeasured confounder would need with BOTH exposure and outcome to explain away the observed effect
- Calculate at: [https://www.evalue-calculator.com/](https://www.evalue-calculator.com/)
- Formula: `E = RR + sqrt(RR × (RR − 1))` for RR > 1
- **BMJ**: Report E-value for primary analysis

---

## 7. Missing Data Methods

| Method | Validity | Efficiency | When |
|:-------|:---------|:-----------|:-----|
| Complete-case (listwise deletion) | MCAR only | Low (loss of power) | < 5% missing, MCAR |
| Available-case | MCAR | Variable | Never recommended alone |
| Last observation carried forward (LOCF) | MCAR | Medium | Avoid — biased under MAR |
| Mean imputation | MCAR | Low | Avoid — distorts distributions |
| Regression imputation | MAR | Medium | Underestimates variance |
| Multiple imputation (MICE) | MAR | High | **Preferred method** |
| Maximum likelihood (FIML) | MAR | High | Uses all available data |
| Pattern-mixture model | MNAR | — | Sensitivity analysis |

> **NEJM editorial**: Multiple imputation is the preferred method for handling missing data in primary analyses. Report: (1) proportion missing per variable, (2) imputation model details, (3) number of imputed datasets (recommend ≥ 20 for ≥ 20% missing).

---

## 8. Multiple Testing Correction

| Method | FWER/FDR | Power | Use Case |
|:-------|:---------|:------|:---------|
| Bonferroni | FWER | Lowest | Primary endpoint protection |
| Holm (step-down) | FWER | Moderate | Stronger than Bonferroni |
| Hochberg (step-up) | FWER | Moderate | Requires positive dependency |
| Sidak | FWER | Moderate | Slightly more powerful than Bonferroni |
| Benjamini-Hochberg (BH) | FDR | High | Exploratory analyses, omics |
| Benjamini-Yekutieli | FDR | Moderate | Any dependency structure |
| False Discovery Rate (Storey) | FDR | Highest | Large-scale testing (GWAS) |

> **JAMA requirement**: When reporting subgroup analyses, specify whether adjustment for multiplicity was applied. If not, state this explicitly as a limitation.

---

## 9. Diagnostic Test Evaluation

### 9.1 Basic Metrics

```
Sensitivity = TP / (TP + FN) — "ability to detect disease"
Specificity = TN / (TN + FP) — "ability to rule out disease"
PPV = TP / (TP + FP) — "probability of disease given positive test"
NPV = TN / (TN + FN) — "probability of no disease given negative test"
Accuracy = (TP + TN) / (TP + FP + TN + FN)
Prevalence = (TP + FN) / Total
```

### 9.2 ROC Analysis

- **AUC**: 0.5 (no discrimination) to 1.0 (perfect)
- **Clinical cutoffs**: Youden index (maximize sensitivity + specificity − 1)
- **Compare AUCs**: DeLong's test for paired ROC curves

### 9.3 Reclassification

| Metric | Interpretation |
|:-------|:---------------|
| NRI | Net Reclassification Improvement: does the new marker correctly reclassify? |
| IDI | Integrated Discrimination Improvement: change in discrimination slope |
| > 0 for both indicates improvement |

---

## 10. Sample Size & Power

### Common Formulas

| Design | Method | Key Parameters |
|:-------|:-------|:---------------|
| Two-group comparison | `power.t.test()` | δ, σ, α, β |
| Proportion comparison | `power.prop.test()` | p1, p2, α, β |
| Survival (log-rank) | `powerSurvEpi::powerCT()` | HR, event rate, α, β |
| Logistic regression | `Hmisc::powerLog()` | OR, R², event rate |
| Correlation | `pwr::pwr.r.test()` | r, α, β |
| ANOVA | `pwr::pwr.anova.test()` | f, k, α, β |
| Non-inferiority | `TrialSize::NonInfEquiv.Test()` | δ, margin, α, β |

### Reporting Standards

- **CONSORT**: Report how sample size was determined, including effect size used
- **Avoid post-hoc power**: "Observed power" is a flawed concept — report 95% CI instead

---

## 11. Common Pitfalls & Reviewer Flags

| Pitfall | Why It's Wrong | What To Do Instead |
|:--------|:---------------|:-------------------|
| Mean ± SE instead of SD | SE is for inference, not description | Use Mean ± SD |
| Stepwise selection | Inflated R², biased coefficients | Use LASSO or DAG-based selection |
| Dichotomizing continuous variables | Loss of power, residual confounding | Use RCS or splines |
| Log-transforming to achieve normality | Difficult to interpret | Use generalized linear models |
| "Post-hoc power calculation" | Mathematically flawed | Report 95% CI |
| Reporting "NS" instead of exact P | Non-informative | Report exact P (e.g., P = 0.34) |
| Interpreting OR as RR when outcome is common | Inflated effect | Use log-binomial or Poisson with robust variance |
| Multiple t-tests for >2 groups | Inflated type I error | ANOVA + post-hoc |
| No correction for multiple outcomes | Inflated type I error | Bonferroni or FDR |
| Subgroup claims without interaction test | Type I error | Test interaction first |
| "No significant difference" means "equivalent" | Type II error | Test for equivalence or report power |

---

## 12. Reporting Guidelines Quick Reference

### STROBE (Observational Studies)
- 22 items covering title, abstract, introduction, methods, results, discussion
- **Key item**: Describe statistical methods including how confounders were identified
- **Key item**: Report numbers of individuals at each stage

### CONSORT (RCTs)
- 25 items + flow diagram
- **Key item**: Method of randomization and allocation concealment
- **Key item**: Whether participants and personnel were blinded
- **Key item**: Include flow diagram of all participants

### STARD (Diagnostic Studies)
- 30 items
- **Key item**: Describe reference standard and its rationale
- **Key item**: Report cross-tabulation of index test vs reference standard

### TRIPOD (Prediction Models)
- 22 items
- **Key item**: Distinguish between development and validation
- **Key item**: Report model performance (discrimination + calibration)

---

## 13. Advanced Topics

### 13.1 Interaction Analysis

```r
# Test interaction term
model <- glm(outcome ~ treatment * subgroup, data = df, family = binomial)
anova(model, test = "Chisq")  # Interaction P-value

# Stratified results
library(broom)
by_subgroup <- df %>% group_by(subgroup) %>%
  do(tidy(glm(outcome ~ treatment, data = ., family = binomial)))
```

**Note**: Never claim subgroup effects without significant interaction test.

### 13.2 Dose-Response Meta-Analysis

- One-stage vs. two-stage approaches
- Linear, quadratic, or spline models
- Include both linear and nonlinear components

### 13.3 Competing Risk Regression

```r
library(cmprsk)
# Sub-distribution hazard (Fine-Gray)
cif <- cuminc(ftime, fstatus, group)
plot(cif)

# Regression
crr_model <- crr(ftime, fstatus, cov1, failcode = 1, cencode = 0)
```

### 13.4 Clinical Prediction Model

**Development vs. Validation:**
- **Internal validation**: cross-validation, bootstrap
- **Temporal validation**: later cohort
- **External validation**: different population

**Metrics:**
- **Discrimination**: C-statistic (AUC for survival)
- **Calibration**: Calibration plot, calibration slope, intercept
- **Overall**: Brier score

---

## References

1. Altman DG. *Practical Statistics for Medical Research*. Chapman & Hall, 1991.
2. Altman DG. *Statistics with Confidence*, 2nd ed. BMJ Books, 2000.
3. Harrell FE. *Regression Modeling Strategies*, 2nd ed. Springer, 2015.
4. Hernán MA, Robins JM. *Causal Inference: What If*. CRC, 2020.
5. van Buuren S. *Flexible Imputation of Missing Data*, 2nd ed. CRC, 2018.
6. Therneau TM, Grambsch PM. *Modeling Survival Data: Extending the Cox Model*. Springer, 2000.
7. Zhou XH, Obuchowski NA, McClish DK. *Statistical Methods in Diagnostic Medicine*, 2nd ed. Wiley, 2011.
8. Rosenbaum PR. *Observational Studies and Experiments*. Springer, 2017.
9. Vittinghoff E. *Regression Methods in Biostatistics*, 2nd ed. Springer, 2012.
10. CONSORT: Schulz KF, et al. *BMJ* 2010;340:c332.
11. STROBE: von Elm E, et al. *BMJ* 2007;335:806.
12. STARD: Bossuyt PM, et al. *BMJ* 2015;351:h5527.
13. TRIPOD: Collins GS, et al. *BMJ* 2015;350:g7594.
