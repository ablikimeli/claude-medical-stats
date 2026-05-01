#!/usr/bin/env Rscript
# ============================================
# Table 1: 基线特征表（单因素分析）
# medical-statistics skill
# ============================================

suppressPackageStartupMessages(library(tableone))
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
    } else if (args[i] == "--outcome" && i + 1 <= length(args)) {
      params$outcome <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--continuous" && i + 1 <= length(args)) {
      params$continuous <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else if (args[i] == "--categorical" && i + 1 <= length(args)) {
      params$categorical <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else if (args[i] == "--nonnormal" && i + 1 <= length(args)) {
      params$nonnormal <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  return(params)
}

params <- parse_args(args)

if (is.null(params$data) || is.null(params$outcome)) {
  stop("请指定: --data <path> --outcome <variable>")
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

# 确保结局变量是因子
df[[params$outcome]] <- as.factor(df[[params$outcome]])

# 自动识别变量类型
all_vars <- setdiff(names(df), params$outcome)

if (is.null(params$continuous)) {
  params$continuous <- all_vars[sapply(df[all_vars], function(x) is.numeric(x) && length(unique(x)) > 10)]
}
if (is.null(params$categorical)) {
  params$categorical <- setdiff(all_vars, params$continuous)
}

# 确保分类变量是因子
for (v in params$categorical) {
  if (v %in% names(df)) {
    df[[v]] <- as.factor(df[[v]])
  }
}

cat("\n═══════════════════════════════════════════\n")
cat("      Table 1: 基线特征表\n")
cat("═══════════════════════════════════════════\n\n")

# 创建 TableOne
tab1 <- CreateTableOne(
  vars = c(params$continuous, params$categorical),
  strata = params$outcome,
  data = df,
  factorVars = params$categorical,
  test = TRUE,
  smd = TRUE
)

# 打印
print(tab1, showAllLevels = TRUE, formatOptions = list(big.mark = ","))

# 提取为数据框
tab1_print <- print(tab1, showAllLevels = TRUE, quote = FALSE, noSpaces = TRUE, printToggle = FALSE)

cat("\n\n━━━━━━━━━━━━━━━━━━ 单因素分析P值汇总 ━━━━━━━━━━━━━━━━━━\n\n")
# 输出P值
pvals <- ExtractPvalue(tab1)
print(pvals, row.names = TRUE)

cat("\n\n━━━━━━━━━━━━━━━━━━ 筛选结果（P < 0.1） ━━━━━━━━━━━━━━━━━━\n")
significant_vars <- rownames(pvals)[pvals$pvalue < 0.1]
if (length(significant_vars) > 0) {
  cat("以下变量 P < 0.1，建议纳入多因素分析：\n")
  for (v in significant_vars) {
    cat(sprintf("  ■ %s (P = %.4f)\n", v, pvals[v, "pvalue"]))
  }
} else {
  cat("没有P < 0.1的变量\n")
}

cat("\n\n━━━━━━━━━━━━━━━━━━ 方法学说明 ━━━━━━━━━━━━━━━━━━\n")
cat(sprintf("连续变量: %s\n", paste(params$continuous, collapse = ", ")))
cat(sprintf("分类变量: %s\n", paste(params$categorical, collapse = ", ")))
cat(sprintf("分组变量: %s\n", params$outcome))
cat("检验方法：\n")
cat("  连续正态: t检验 / ANOVA\n")
cat("  连续非正态: Wilcoxon秩和检验 / Kruskal-Wallis\n")
cat("  分类变量: χ²检验 / Fisher精确检验\n")

# ---- Export results to Excel and Word ----
suppressPackageStartupMessages(library(openxlsx))
suppressPackageStartupMessages(library(flextable))
suppressPackageStartupMessages(library(officer))

ts_val <- format(Sys.time(), "%Y%m%d_%H%M%S")

tab1_print <- print(tab1, showAllLevels = TRUE, quote = FALSE, noSpaces = TRUE, printToggle = FALSE)
tab1_export <- as.data.frame.matrix(tab1_print)
tab1_export <- cbind(Variable = rownames(tab1_export), tab1_export)
rownames(tab1_export) <- NULL

excel_file <- paste0("table1_", ts_val, ".xlsx")
write.xlsx(tab1_export, excel_file, overwrite = TRUE)
cat(sprintf("\n  ✔ Excel: %s\n", excel_file))

word_file <- paste0("table1_", ts_val, ".docx")
ft <- flextable(tab1_export) %>%
  theme_booktabs() %>% autofit() %>%
  bold(part = "header") %>% align(align = "center", part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>% fontsize(size = 9, part = "all")
doc <- read_docx() %>%
  body_add_par("Table 1: Baseline Characteristics", style = "heading 1") %>%
  body_add_flextable(ft)
print(doc, target = word_file)
cat(sprintf("  ✔ Word: %s\n", word_file))

pvals <- ExtractPvalue(tab1)
pval_df <- data.frame(Variable = rownames(pvals), P_value = round(pvals$pvalue, 4), row.names = NULL)
write.xlsx(pval_df, paste0("table1_pvalues_", ts_val, ".xlsx"), overwrite = TRUE)
cat(sprintf("  ✔ P-values: table1_pvalues_%s.xlsx\n", ts_val))

cat("\n═══════════════════════════════════════════\n")
