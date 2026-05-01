#!/usr/bin/env Rscript
# ============================================
# 正态性检验脚本
# medical-statistics skill
# ============================================

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(readxl))

args <- commandArgs(trailingOnly = TRUE)

parse_args <- function(args) {
  params <- list()
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--data" && i + 1 <= length(args)) {
      params$data <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--vars" && i + 1 <= length(args)) {
      params$vars <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  return(params)
}

params <- parse_args(args)

if (is.null(params$data)) {
  stop("请指定数据文件路径: --data <path>")
}

# 读取数据
ext <- tolower(tools::file_ext(params$data))
if (ext == "csv") {
  df <- read.csv(params$data, stringsAsFactors = FALSE)
} else if (ext %in% c("xls", "xlsx")) {
  df <- read_excel(params$data)
} else if (ext %in% c("sav")) {
  df <- read_sav(params$data)
} else if (ext %in% c("dta")) {
  df <- read_dta(params$data)
} else {
  stop("不支持的文件格式: ", ext)
}

# 自动识别连续变量
if (is.null(params$vars)) {
  continuous_vars <- names(df)[sapply(df, function(x) is.numeric(x) && length(unique(x)) > 10)]
} else {
  continuous_vars <- params$vars[params$vars %in% names(df)]
}

cat("\n═══════════════════════════════════════════\n")
cat("        正态性检验结果\n")
cat("═══════════════════════════════════════════\n\n")

results <- data.frame(
  变量 = character(),
  样本量 = integer(),
  均值 = numeric(),
  标准差 = numeric(),
  中位数 = numeric(),
  Q1 = numeric(),
  Q3 = numeric(),
  偏度 = numeric(),
  峰度 = numeric(),
  Shapiro_P = numeric(),
  正态性判断 = character(),
  stringsAsFactors = FALSE
)

for (var in continuous_vars) {
  x <- df[[var]]
  x <- x[!is.na(x)]
  n <- length(x)

  if (n < 3) {
    cat(sprintf("  ⚠ %s: 样本量不足 (%d)，跳过\n", var, n))
    next
  }

  mean_val <- mean(x, na.rm = TRUE)
  sd_val <- sd(x, na.rm = TRUE)
  median_val <- median(x, na.rm = TRUE)
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)

  # 偏度峰度
  skewness <- sum((x - mean_val)^3) / (n * sd_val^3)
  kurtosis <- sum((x - mean_val)^4) / (n * sd_val^4) - 3

  # Shapiro-Wilk 检验
  if (n < 5000 && n >= 3) {
    sw_test <- shapiro.test(x)
    shapiro_p <- sw_test$p.value
  } else if (n >= 5000) {
    # KS 检验
    ks_test <- ks.test(x, "pnorm", mean_val, sd_val)
    shapiro_p <- ks_test$p.value
  } else {
    shapiro_p <- NA
  }

  # 判断
  if (!is.na(shapiro_p)) {
    if (shapiro_p > 0.05) {
      normality <- "正态分布"
    } else if (shapiro_p > 0.01) {
      normality <- "弱非正态"
    } else {
      normality <- "非正态分布"
    }
  } else {
    normality <- "无法判断"
  }

  results <- rbind(results, data.frame(
    变量 = var,
    样本量 = n,
    均值 = round(mean_val, 3),
    标准差 = round(sd_val, 3),
    中位数 = round(median_val, 3),
    Q1 = round(q1, 3),
    Q3 = round(q3, 3),
    偏度 = round(skewness, 3),
    峰度 = round(kurtosis, 3),
    Shapiro_P = round(shapiro_p, 4),
    正态性判断 = normality,
    stringsAsFactors = FALSE
  ))

  # 输出单个变量详情
  cat(sprintf("  ■ %s (n=%d)\n", var, n))
  cat(sprintf("    正态性检验 P = %.4f\n", shapiro_p))
  if (shapiro_p > 0.05) {
    cat(sprintf("    ✅ 正态分布 (P > 0.05)\n"))
    cat(sprintf("    描述方式: Mean ± SD = %.2f ± %.2f\n", mean_val, sd_val))
  } else {
    cat(sprintf("    ❌ 非正态分布 (P ≤ 0.05)\n"))
    cat(sprintf("    描述方式: Median (Q1, Q3) = %.2f (%.2f, %.2f)\n", median_val, q1, q3))
  }
  cat("    -----------------------------------\n")
}

# 输出汇总表
cat("\n━━━━━━━━━━━━━━━━━━ 汇总 ━━━━━━━━━━━━━━━━━━\n")
print(results, row.names = FALSE)

# 输出建议的描述方式和检验方法
cat("\n━━━━━━━━━━━━━━━━━━ 统计方法建议 ━━━━━━━━━━━━━━━━━━\n")
for (i in seq_len(nrow(results))) {
  if (results$正态性判断[i] %in% c("正态分布", "弱非正态")) {
    desc <- sprintf("Mean ± SD (%.2f ± %.2f)", results$均值[i], results$标准差[i])
    test <- "t检验 / ANOVA (参数检验)"
  } else {
    desc <- sprintf("Median (Q1, Q3) = %.2f (%.2f, %.2f)", results$中位数[i], results$Q1[i], results$Q3[i])
    test <- "Wilcoxon秩和检验 / Kruskal-Wallis检验 (非参数检验)"
  }
  cat(sprintf("  %s:\n", results$变量[i]))
  cat(sprintf("    描述: %s\n", desc))
  cat(sprintf("    推荐方法: %s\n", test))
}

cat("\n═══════════════════════════════════════════\n")
