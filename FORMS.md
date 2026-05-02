# Interaction Templates — Method Selection & Review

## 1. Method Recommendation Template

```
══════════════════════════════════════════════════
  Statistical Method Recommendation
══════════════════════════════════════════════════

Variable: {variable_name}
Type: {continuous / categorical / ordinal}
Distribution: {normal / non-normal / pending test}
Comparison: {two-group / multi-group / paired}

Recommended Method: {recommended_method}
Rationale:
  1. {rationale_1}
  2. {rationale_2}
  3. {rationale_3}

Alternatives Considered:
  - {alternative_1}: {reason_not_chosen}
  - {alternative_2}: {reason_not_chosen}

Do you agree with this recommendation?
  [1] Yes — proceed with recommended method
  [2] No — I have a custom method in mind
══════════════════════════════════════════════════
```

## 2. Custom Method Evaluation Template

```
══════════════════════════════════════════════════
  Custom Method Evaluation
══════════════════════════════════════════════════

User's Chosen Method: {custom_method}
Assessment: {✅ Appropriate / ⚠ Needs Caution / ❌ Inappropriate}

Detailed Assessment:
  {assessment_details}

Recommended Alternative: {suggested_method}
Reason: {reason_suggestion_is_better}

Options:
  [1] Accept recommended method — {suggested_method}
  [2] Insist on custom method — results will be annotated:
      "[Method specified by user — not validated for this context]"
══════════════════════════════════════════════════
```

## 3. Model Results Report Template

```
══════════════════════════════════════════════════
  {Model_Type} Results
══════════════════════════════════════════════════

 Variable         │ Effect (95% CI)      │ P-value    │
──────────────────┼──────────────────────┼────────────
 {var1}           │ {effect} ({ci_low}–{ci_high}) │ {p}   {sig}
 {var2}           │ {effect} ({ci_low}–{ci_high}) │ {p}   {sig}
 {var3}           │ {effect} ({ci_low}–{ci_high}) │ {p}   {sig}

───────────────────────────────────────────────────────
Model Performance:
  • Discrimination: C-statistic / AUC = {value} (95% CI: {ci})
  • Calibration: {test_name} P = {p}
  • Multicollinearity: max VIF = {max_vif}
  • Events per variable (EPV) = {epv}  [{status}]

───────────────────────────────────────────────────────
```

## 4. Comprehensive Report Template

```
# Statistical Analysis Report

## Study Design
- Design: {RCT / Cohort / Case-Control / Cross-sectional}
- Primary objective: {objective}
- Sample size: N = {n_total}

## Data Quality
- Complete cases: {n_complete} ({pct_complete}%)
- Missing data method: {method}
- Outliers detected: {n_outliers}

## Methods
- Continuous variables: Normal → Mean±SD / parametric; Non-normal → Median(IQR) / non-parametric
- Categorical variables: n(%) / χ²-test or Fisher's exact
- Multivariable method: {model_type} adjusted for {covariates}
- Non-linear analysis: Restricted cubic splines ({k} knots)
- Sensitivity analyses: {list_sensitivity_methods}

## User Interaction Log
- {method_1}: Recommended {recommended} → User {agreed / specified custom: {custom}}
- {method_2}: Recommended {recommended} → User {agreed / specified custom: {custom}}
- {method_3}: Recommended {recommended} → User {agreed / specified custom: {custom}}

## Key Results
[Summary tables and figures]

## Exported Files
- Table 1 (CSV): `table1_{timestamp}.csv`
- Table 1 (Excel): `table1_{timestamp}.xlsx`
- Table 1 (Word): `table1_{timestamp}.docx`
- Multivariable results (CSV): `{model_type}_{timestamp}.csv`
- Multivariable results (Excel): `{model_type}_{timestamp}.xlsx`
- Multivariable results (Word): `{model_type}_{timestamp}.docx`
- Forest plot (PNG): `forest_{model_type}_{timestamp}.png`
- Forest plot (PDF): `forest_{model_type}_{timestamp}.pdf`
- RCS plot (PNG): `rcs_{variable}_{timestamp}.png`
- RCS plot (PDF): `rcs_{variable}_{timestamp}.pdf`
- RCS prediction data (Excel): `rcs_{variable}_data_{timestamp}.xlsx`
- Normality results (CSV): `normality_{timestamp}.csv`
- Normality plots (PNG): `normality_{variable}_{timestamp}.png`
- Normality plots (PDF): `normality_{variable}_{timestamp}.pdf`
- ROC curve (PNG): `roc_curve_{timestamp}.png`
- ROC curve (PDF): `roc_curve_{timestamp}.pdf`

## Journal Reviewer Assessment
{reviewer_comments}

## Limitations
{limitations}

---
Generated: {timestamp}
Tool: Claude Code — medical-statistics skill
Reviewer Standard: {Lancet / BMJ / NEJM / JAMA} statistical review criteria
```

## 5. Journal Statistical Review Template

```
══════════════════════════════════════════════════
  Journal Statistical Review
══════════════════════════════════════════════════

Manuscript: {title}

┌─────────────────────────────────────────────────────┐
│ Domain               │ Rating │ Comments            │
├─────────────────────────────────────────────────────┤
│ Study Design         │ {1-5}  │ {comment}           │
│ Sample Size / Power  │ {1-5}  │ {comment}           │
│ Handling of Missing  │ {1-5}  │ {comment}           │
│ Confounding Control  │ {1-5}  │ {comment}           │
│ Model Assumptions    │ {1-5}  │ {comment}           │
│ Subgroup Analysis    │ {1-5}  │ {comment}           │
│ Multiple Testing     │ {1-5}  │ {comment}           │
│ Reporting Quality    │ {1-5}  │ {comment}           │
│ Figures & Tables     │ {1-5}  │ {comment}           │
│ Interpretation       │ {1-5}  │ {comment}           │
└─────────────────────────────────────────────────────┘

Overall Assessment: {accept / minor / major / reject}
Critical Issues: {count}
Major Issues: {count}
Minor Issues: {count}

Recommendation: {recommendation}
══════════════════════════════════════════════════
```

## 6. Missing Data Report Template

```
══════════════════════════════════════════════════
  Missing Data Assessment
══════════════════════════════════════════════════

Variable          │ N Missing │ % Missing │ Pattern
──────────────────┼───────────┼───────────┼─────────
{variable_1}      │ {n}       │ {pct}%    │ {pattern}
{variable_2}      │ {n}       │ {pct}%    │ {pattern}

Likely Mechanism: {MCAR / MAR / MNAR}
Recommended Approach: {approach}

Options:
  [1] Complete-case analysis (if missing < 5% AND MCAR)
  [2] Multiple imputation (if MAR)
  [3] User has alternative approach
══════════════════════════════════════════════════
```

## 7. E-value Report Template

```
══════════════════════════════════════════════════
  E-value Sensitivity Analysis
══════════════════════════════════════════════════

Observed Effect: {OR/HR/β} = {value} (95% CI: {ci_low}–{ci_high})

E-value for point estimate: {e_value_est}
  Interpretation: An unmeasured confounder would need a risk ratio
  of ≥ {e_value_est} with BOTH exposure and outcome to explain away
  the observed effect estimate{for_linear: ; for linear regression, the E-value
  is expressed on the risk ratio scale and requires converting β to an approximate RR}.

E-value for CI limit: {e_value_ci}
  Interpretation: An unmeasured confounder would need a risk ratio
  of ≥ {e_value_ci} to shift the CI to include the null.

Robustness: {robust / moderate / fragile}
══════════════════════════════════════════════════
```
