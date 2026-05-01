#!/usr/bin/env Rscript
# ============================================
# Export utilities: Word, Excel, PDF+PNG
# medical-statistics skill
# ============================================

#' Export a data frame to Excel (.xlsx)
#' @param df data.frame to export
#' @param filename Output file path
#' @param sheet_name Sheet name (max 31 chars)
#' @param title Optional title row at top
export_to_excel <- function(df, filename, sheet_name = "Results", title = NULL) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    install.packages("openxlsx", repos = "https://cran.r-project.org")
  }
  library(openxlsx)

  wb <- createWorkbook()
  addWorksheet(wb, sheet_name)

  start_row <- 1
  if (!is.null(title)) {
    mergeCells(wb, sheet_name, cols = seq_len(ncol(df)), rows = 1)
    writeData(wb, sheet_name, title, startCol = 1, startRow = 1)
    addStyle(wb, sheet_name, createStyle(textDecoration = "bold", fontSize = 13), rows = 1, cols = 1)
    start_row <- 2
  }

  writeData(wb, sheet_name, df, startCol = 1, startRow = start_row,
            headerStyle = createStyle(textDecoration = "bold", border = "bottom",
                                       fgFill = "#D9E1F2"))
  setColWidths(wb, sheet_name, cols = seq_len(ncol(df)), widths = "auto")

  saveWorkbook(wb, filename, overwrite = TRUE)
  cat(sprintf("  ✔ Excel exported: %s\n", normalizePath(filename)))
  return(invisible(filename))
}

#' Export a data frame to Word (.docx) as a formatted table
#' @param df data.frame to export
#' @param filename Output file path
#' @param title Optional title text above the table
export_to_word <- function(df, filename, title = NULL) {
  if (!requireNamespace("flextable", quietly = TRUE)) {
    install.packages("flextable", repos = "https://cran.r-project.org")
  }
  if (!requireNamespace("officer", quietly = TRUE)) {
    install.packages("officer", repos = "https://cran.r-project.org")
  }
  library(flextable)
  library(officer)

  ft <- flextable(df) %>%
    theme_booktabs() %>%
    autofit() %>%
    bold(part = "header") %>%
    align(align = "center", part = "all") %>%
    font(fontname = "Times New Roman", part = "all") %>%
    fontsize(size = 10, part = "all") %>%
    padding(padding = 3, part = "all")

  # Add header background
  ft <- bg(ft, bg = "#D9E1F2", part = "header")

  doc <- read_docx()
  if (!is.null(title)) {
    doc <- doc %>%
      body_add_par(title, style = "heading 1") %>%
      body_add_par("", style = "Normal")  # spacer
  }
  doc <- doc %>%
    body_add_flextable(ft) %>%
    body_add_par("", style = "Normal")

  print(doc, target = filename)
  cat(sprintf("  ✔ Word exported: %s\n", normalizePath(filename)))
  return(invisible(filename))
}

#' Save a ggplot2 figure as both PNG and PDF
#' @param plot ggplot object
#' @param basename Base filename (without extension)
#' @param width Width in inches (default 8)
#' @param height Height in inches (default 6)
save_plot_dual <- function(plot, basename, width = 8, height = 6) {
  # PNG
  png_file <- paste0(basename, ".png")
  ggsave(png_file, plot, width = width, height = height, dpi = 300)
  cat(sprintf("  ✔ PNG saved: %s\n", normalizePath(png_file)))

  # PDF
  pdf_file <- paste0(basename, ".pdf")
  ggsave(pdf_file, plot, width = width, height = height, device = "pdf")
  cat(sprintf("  ✔ PDF saved: %s\n", normalizePath(pdf_file)))

  return(invisible(c(png_file, pdf_file)))
}

#' Generate a timestamp string for filenames
ts <- function() {
  format(Sys.time(), "%Y%m%d_%H%M%S")
}

cat("✔ export_utils.R loaded\n")
