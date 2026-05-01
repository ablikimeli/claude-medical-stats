#!/usr/bin/env Rscript
# ============================================
# 多因素回归分析脚本
# medical-statistics skill
# ============================================

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(readxl))
suppressPackageStartupMessages(library(survival))

args <- commandArgs(trailingOnly = TRUE)

parse_args <- function(args) {
  params <- list()
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--data" && i + 1 <= length(args)) {
      params$data <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--outcome" && i + 1 <= length(args)) {
      params$outcome <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--type" && i + 1 <= length(args)) {
      params$type <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--vars" && i + 1 <= length(args)) {
      params$vars <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else if (args[i] == "--time" && i + 1 <= length(args)) {
      params$time <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--pthreshold" && i + 1 <= length(args)) {
      params$pthreshold <- as.numeric(args[i + 1])
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  return(params)
}

params <- parse_args(args)

if (is.null(params$data) || is.null(params$outcome) || is.null(params$type)) {
  stop("请指定: --data <path> --outcome <variable> --type <linear|logistic|cox>")
}

if (is.null(params$pthreshold)) params$pthreshold <- 0.1

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

# 构建公式
if (is.null(params$vars)) {
  # 所有其他变量作为自变量
  if (params$type == "cox") {
    if (is.null(params$time)) stop("Cox回归需要指定 --time")
    vars <- setdiff(names(df), c(params$outcome, params$time))
  } else {
    vars <- setdiff(names(df), params$outcome)
  }
} else {
  vars <- params$vars[vars %in% names(df)]
}

cat("\n═══════════════════════════════════════════\n")
cat(sprintf("     多因素分析: %s回归\n", switch(params$type,
  "linear" = "线性",
  "logistic" = "Logistic",
  "cox" = "Cox比例风险"
)))
cat("═══════════════════════════════════════════\n\n")

cat("纳入变量:", paste(vars, collapse = ", "), "\n\n")

# 执行回归
if (params$type == "linear") {
  formula <- as.formula(paste(params$outcome, "~", paste(vars, collapse = " + ")))
  model <- lm(formula, data = df)
  s <- summary(model)

  cat("━━━ 模型摘要 ━━━\n")
  cat(sprintf("R² = %.4f, 调整R² = %.4f\n", s$r.squared, s$adj.r.squared))
  cat(sprintf("F = %.4f, P = %.4e\n\n", s$fstatistic[1], pf(s$fstatistic[1], s$fstatistic[2], s$fstatistic[3], lower.tail = FALSE)))

  coef_df <- as.data.frame(coef(s))
  names(coef_df) <- c("β", "Std.Error", "t_value", "P_value")

  cat("━━━ 回归系数 ━━━\n")
  result <- data.frame(
    变量 = rownames(coef_df),
    β = round(coef_df$β, 4),
    SE = round(coef_df$Std.Error, 4),
    t = round(coef_df$t_value, 3),
    P = round(coef_df$P_value, 4),
    `95%CI_L` = round(coef_df$β - 1.96 * coef_df$Std.Error, 4),
    `95%CI_U` = round(coef_df$β + 1.96 * coef_df$Std.Error, 4),
    stringsAsFactors = FALSE
  )
  result$显著性 <- ifelse(result$P < 0.001, "***",
                   ifelse(result$P < 0.01, "**",
                   ifelse(result$P < 0.05, "*", "")))
  print(result, row.names = FALSE)

} else if (params$type == "logistic") {
  df[[params$outcome]] <- as.factor(df[[params$outcome]])
  formula <- as.formula(paste(params$outcome, "~", paste(vars, collapse = " + ")))
  model <- glm(formula, data = df, family = binomial())
  s <- summary(model)

  or <- exp(coef(model))
  ci <- exp(confint(model))

  cat("━━━ Logistic回归结果 (OR) ━━━\n\n")
  result <- data.frame(
    变量 = names(coef(model)),
    OR = round(or, 4),
    `95%CI_L` = round(ci[, 1], 4),
    `95%CI_U` = round(ci[, 2], 4),
    P = round(coef(s)[, 4], 4),
    stringsAsFactors = FALSE
  )
  result$OR_CI <- sprintf("%.3f (%.3f-%.3f)", result$OR, result$X95CI_L, result$X95CI_U)
  result$显著性 <- ifelse(result$P < 0.001, "***",
                   ifelse(result$P < 0.01, "**",
                   ifelse(result$P < 0.05, "*", "")))
  print(result[, c("变量", "OR_CI", "P", "显著性")], row.names = FALSE)

} else if (params$type == "cox") {
  formula <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ ", paste(vars, collapse = " + ")))
  model <- coxph(formula, data = df)
  s <- summary(model)

  hr <- exp(coef(model))
  ci <- exp(confint(model))

  cat("━━━ Cox回归结果 (HR) ━━━\n\n")
  result <- data.frame(
    变量 = names(hr),
    HR = round(hr, 4),
    `95%CI_L` = round(ci[, 1], 4),
    `95%CI_U` = round(ci[, 2], 4),
    P = round(s$coefficients[, "Pr(>|z|)"], 4),
    stringsAsFactors = FALSE
  )
  result$HR_CI <- sprintf("%.3f (%.3f-%.3f)", result$HR, result$X95CI_L, result$X95CI_U)
  result$显著性 <- ifelse(result$P < 0.001, "***",
                   ifelse(result$P < 0.01, "**",
                   ifelse(result$P < 0.05, "*", "")))
  print(result[, c("变量", "HR_CI", "P", "显著性")], row.names = FALSE)
}

cat("\n\n━━━━━━━━━━━━━━━━━━ 模型信息 ━━━━━━━━━━━━━━━━━━\n")
cat(sprintf("回归类型: %s\n", params$type))
cat(sprintf("样本量: %d\n", nrow(model$model)))
cat(sprintf("变量数: %d\n", length(vars)))

cat("\n═══════════════════════════════════════════\n")
