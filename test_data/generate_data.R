#!/usr/bin/env Rscript
# ============================================
# 合成临床数据集生成器
# 用于验证 medical-statistics skill
# N = 800, 包含连续/二分类/生存三种结局
# 真实已知关系可验证模型能否正确检出
# ============================================

set.seed(20260502)
n <- 800

cat("══════════════════════════════════════════\n")
cat("  合成临床数据生成器\n")
cat("══════════════════════════════════════════\n\n")

# ── 人口学变量 ──
age <- round(rnorm(n, 60, 12), 1)
age <- pmin(pmax(age, 35), 85)
age_std <- (age - 60) / 10                   # 标准化: 每10岁

gender <- factor(
  sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.48, 0.52))
)

bmi <- round(rnorm(n, 26, 4.5), 1)
bmi <- pmin(pmax(bmi, 16), 40)

education <- factor(
  sample(c("Low", "Middle", "High"), n, replace = TRUE, prob = c(0.30, 0.40, 0.30)),
  levels = c("Low", "Middle", "High"),
  ordered = TRUE
)

# ── 生活方式 ──
smoking <- factor(
  sample(c("Never", "Former", "Current"), n, replace = TRUE,
         prob = c(0.50, 0.28, 0.22)),
  levels = c("Never", "Former", "Current")
)

alcohol <- factor(
  sample(c("Never", "Moderate", "Heavy"), n, replace = TRUE,
         prob = c(0.55, 0.30, 0.15)),
  levels = c("Never", "Moderate", "Heavy")
)

# ── 临床指标 ──
sbp       <- round(115 + 0.4 * age + rnorm(n, 0, 12), 0)
dbp       <- round(72 + 0.15 * age + rnorm(n, 0, 8), 0)
ldl       <- round(2.6 + 0.01 * age + rnorm(n, 0, 0.7), 2)
hdl       <- round(1.5 - 0.005 * age + 0.3 * (gender == "Female") + rnorm(n, 0, 0.3), 2)
glucose   <- round(5.0 + 0.02 * age + 0.3 * (bmi > 28) + rnorm(n, 0, 0.9), 2)
creatinine <- round(70 + 0.2 * age + rnorm(n, 0, 14), 1)

# ── 治疗分配 (随机) ──
treatment <- factor(
  sample(c("Control", "Active"), n, replace = TRUE, prob = c(0.5, 0.5)),
  levels = c("Control", "Active")
)
treatment_bin <- ifelse(treatment == "Active", 1, 0)

cat(sprintf("  N = %d\n", n))
cat(sprintf("  年龄: %.1f ± %.1f (%.0f-%.0f)\n", mean(age), sd(age), min(age), max(age)))
cat(sprintf("  女性: %.1f%%\n", mean(gender == "Female") * 100))
cat(sprintf("  BMI: %.1f ± %.1f\n", mean(bmi), sd(bmi)))
cat(sprintf("  治疗组(Active): %.1f%%\n", mean(treatment == "Active") * 100))

# ============================================
# 结局变量生成
# 记录真实效应，供验证使用
# ============================================

# ── 1. 连续结局 (biomarker) — 线性回归 ──
# 真实模型:
#   biomarker = 45  -1.2*age_std + 0.08*(bmi-25)^2 + 2.5*treatment + ε
#   - age: 每10岁降低1.2 (线性负相关)
#   - bmi: U型关系，BMI=25时最低 (验证RCS)
#   - treatment: Active组升高2.5
biomarker <- round(45 +
  -1.2 * age_std +
  0.08 * (bmi - 25)^2 +
  2.5 * treatment_bin +
  rnorm(n, 0, 5), 2)

# ── 2. 二分类结局 (event) — Logistic 回归 ──
# 真实模型:
#   logit(P) = -2.0 + 0.35*age_std + 0.5*max(age_std,0)^2
#              + 0.35*ldl + 0.7*(smoking=Current)
#              + 0.3*(smoking=Former) - 0.65*treatment
#   - age: J型关系，65岁后风险陡增 (验证RCS非线性)
#   - ldl: 每1 mmol/L OR=1.42
#   - smoking: Current OR=2.01, Former OR=1.35
#   - treatment: Active OR=0.52 (保护)
x_age_lin    <- age_std
x_age_nonlin <- pmax(age_std, 0)^2
logit_p <- -2.0 +
  0.35 * x_age_lin +
  0.50 * x_age_nonlin +
  0.35 * ldl +
  0.70 * (smoking == "Current") +
  0.30 * (smoking == "Former") -
  0.65 * treatment_bin

event_prob <- plogis(logit_p)
event <- as.numeric(rbinom(n, 1, event_prob) == 1)
cat(sprintf("  事件率 (binary): %.1f%%\n", mean(event) * 100))

# ── 3. 生存结局 (surv_time + surv_status) — Cox 回归 ──
# 真实模型:
#   h(t) = h0(t) * exp(0.5*age_std + 0.3*(smoking=Current) - 0.5*treatment)
#   - age: HR=1.65 每10岁
#   - smoking Current: HR=1.35
#   - treatment Active: HR=0.61
true_hazard <- exp(
  0.50 * age_std +
  0.30 * (smoking == "Current") -
  0.50 * treatment_bin
)
# 使用独立种子，避免之前大量随机数消耗影响 RNG 状态
set.seed(20260503)
surv_time   <- round(rexp(n, 0.010 * true_hazard), 2)
censor_time <- round(rexp(n, 0.030), 2)
surv_status <- as.numeric(surv_time <= censor_time)
surv_observed <- pmin(surv_time, censor_time)
cat(sprintf("  事件率 (survival): %.1f%%\n", mean(surv_status) * 100))
cat(sprintf("  中位生存时间: %.1f\n", median(surv_observed)))
cat(sprintf("  HR范围: %.2f-%.2f\n", min(true_hazard), max(true_hazard)))

# ── 组装完整数据集 ──
df <- data.frame(
  id          = 1:n,
  age         = age,
  gender      = gender,
  bmi         = bmi,
  education   = education,
  smoking     = smoking,
  alcohol     = alcohol,
  sbp         = sbp,
  dbp         = dbp,
  ldl         = ldl,
  hdl         = hdl,
  glucose     = glucose,
  creatinine  = creatinine,
  treatment   = treatment,
  biomarker   = biomarker,
  event       = event,
  surv_time   = surv_observed,  # 观察时间 (min of event/censor)
  surv_status = surv_status,
  stringsAsFactors = FALSE
)

# ── 导出完整数据集 ──
outdir <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)[1]), mustWork = FALSE))
if (is.na(outdir) || outdir == ".") outdir <- getwd()
outdir <- "."

write.csv(df, file.path(outdir, "clinical_data.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("\n  ✔ clinical_data.csv (%d obs × %d vars)\n", nrow(df), ncol(df)))

# ── 含缺失值版本 (~8% MCAR) ──
set.seed(20260502)
df_miss <- df
miss_vars <- c("ldl", "hdl", "glucose", "creatinine", "sbp", "bmi")
for (col in miss_vars) {
  idx <- sample(1:n, size = round(n * 0.08), replace = FALSE)
  df_miss[idx, col] <- NA
}
# 计算实际缺失率
miss_pct <- sapply(df_miss[, miss_vars], function(x) mean(is.na(x)) * 100)
cat("  缺失率:\n")
for (v in miss_vars) cat(sprintf("    %s: %.1f%%\n", v, miss_pct[v]))

write.csv(df_miss, file.path(outdir, "clinical_data_missing.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("  ✔ clinical_data_missing.csv (%d obs, 有缺失值)\n", nrow(df_miss)))

# ── 验证: 打印真实效应摘要 ──
cat("\n━━━ 真实效应 (用于验证) ━━━━━━━━━━━━━━━━━━━\n")
cat("\n【连续结局 biomarker】\n")
cat("  age_std:           β = -1.20 (每10岁)\n")
cat("  (bmi-25)^2:        β = +0.08 (U型, 最低BMI=25)\n")
cat("  treatment(Active): β = +2.50\n")

cat("\n【二分类结局 event】\n")
cat("  age (线性):              OR = exp(0.35) = 1.42 (每10岁)\n")
cat("  age (非线性, J型):       OR = exp(0.50×max(z,0)²) — 65岁后风险陡增\n")
cat("  ldl:                     OR = exp(0.35) = 1.42 (每1 mmol/L)\n")
cat("  smoking(Current):        OR = exp(0.70) = 2.01\n")
cat("  smoking(Former):         OR = exp(0.30) = 1.35\n")
cat("  treatment(Active):       OR = exp(-0.65) = 0.52\n")

cat("\n【生存结局 surv】\n")
cat("  age_std:           HR = exp(0.50) = 1.65 (每10岁)\n")
cat("  smoking(Current):  HR = exp(0.30) = 1.35\n")
cat("  treatment(Active): HR = exp(-0.50) = 0.61\n")

cat("\n══════════════════════════════════════════\n")
cat("  数据生成完成！\n")
cat("  使用指南:\n")
cat("  /medical-statistics\n")
cat("  然后上传 clinical_data.csv 或 clinical_data_missing.csv\n")
cat("══════════════════════════════════════════\n")
