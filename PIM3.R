library(odbc)
library(DBI)
library(dplyr)

con <- dbConnect(odbc(), "Metavision reporting")
dta <- dbReadTable(con, Id(schema = "ANZ1", table = "V_ANZPICR_Admission_Submission"))

# PIM3 Calculation Function data must use the field names of ANZPICR data dictionary available here https://www.anzics.org/wp-content/uploads/2026/02/ANZPICR-Data-Dictionary.pdf
# models availabble anz13, anz15, default = original published model
calculate_pim3 <- function(data, model = "") {
  model <- tolower(model)
  data <- data |> 
    mutate(across(all_of(c("SBPA","PO2A","FIO2A", "BEA", "BE_SOURCE", "RECOVERY", "BYPASS", "PDX", "PIM3_VHR", "PIM3_HR", "PIM_LR", "PUPILS", "ELECTIVE", "RS_HR124")), as.numeric), .keep = "none") |>
    mutate(across(all_of(c("SBPA","PO2A","FIO2A", "BEA", "BE_SOURCE")), ~na_if(., 999))) |>
    mutate(across(all_of(c("PUPILS", "SBPA", "RECOVERY", "ELECTIVE", "BYPASS", "RS_HR124", "PIM3_VHR", "PIM3_HR", "PIM_LR")), ~tidyr::replace_na(., 0))) |>
    mutate(
      fp_ratio = coalesce(FIO2A * 100 / PO2A, 0.23),
      BEA =  coalesce(ifelse(BE_SOURCE %in% c(1, 2), BEA, 0), 0),
      Recov_CardBypPr = if_else(RECOVERY==1 & BYPASS %in% c(1, 3) & PDX >= 1900 & PDX <=1999, 1, 0, missing = 0),
      Recov_CardNonBypPr = if_else(RECOVERY==1 & BYPASS %in% c(0, 2) & PDX %in% c(1900,1999,1102,1106,1107), 1, 0, missing = 0),
      Recov_NonCardPr = if_else(RECOVERY==1 & (PDX %in% c(1100,1101,1103, 1104, 1105) | (PDX >=1108 & PDX <= 1899)), 1, 0, missing = 0),
      PIM3_VHR = if_else(PIM3_VHR %in% c(0, 6), 0, 1, missing = 0),
      PIM3_HR = if_else(PIM3_HR %in% c(0, 5), 0, 1, missing = 0),
      PIM_LR = if_else(PIM_LR > 0, 1, 0, missing = 0))
  if (model == "anz13") {
    data <- data |> mutate(
      logit = (4.371172 * PUPILS) +
              (-0.5164336 * ELECTIVE) +
              (0.6634843 * RS_HR124) +
              (0.0740947 * abs(BEA)) + 
              (-0.0296888 * SBPA) +
              (0.0964949  * ((SBPA^2) / 1000)) +
              (0.5181944 * fp_ratio) +
              (-1.866951 * Recov_CardBypPr) +
              (-1.318171 * Recov_CardNonBypPr) +
              (-1.572421 * Recov_NonCardPr) +
              (1.993498 * PIM3_VHR) +
              (1.368355 * PIM3_HR) +
              (-2.401701 * PIM_LR) -
              2.299542 
    )
  } else if (model == "anz15") {
    data <- data |> mutate(
      logit = (4.524262 * PUPILS) +
              (-0.3676672 * ELECTIVE) +
              (1.062791 * RS_HR124) +
              (0.0651518 * abs(BEA)) + 
              (-0.0359887 * SBPA) +
              (0.1214007 * ((SBPA^2) / 1000)) +
              (0.2747865 * fp_ratio) +
              (-2.302574 * Recov_CardBypPr) +
              (-1.40127 * Recov_CardNonBypPr) +
              (-2.040691 * Recov_NonCardPr) +
              (2.202997 * PIM3_VHR) +
              (1.460924 * PIM3_HR) +
              (-1.750197 * PIM_LR) -
              2.189059
    )  
  } else {
    data <- data |> mutate(
      logit = (3.8233 * PUPILS) +
              (-0.5378 * ELECTIVE) +
              (0.9763 * RS_HR124) +
              (0.0671 * abs(BEA)) + 
              (-0.0431 * SBPA) +
              (0.1716 * ((SBPA^2) / 1000)) +
              (0.4214 * fp_ratio) +
              (-1.2246 * Recov_CardBypPr) +
              (-0.8762 * Recov_CardNonBypPr) +
              (-1.5164 * Recov_NonCardPr) +
              (1.6225 * PIM3_VHR) +
              (1.0725 * PIM3_HR) +
              (-2.1766 * PIM_LR) -
              1.7928
    )
  }
  data |> mutate(
      prob_death = exp(logit) / (1 + exp(logit))
  )
}

df <- calculate_pim3(dta, "anz15")
df$adm <- as.Date(dta$ADM_DT, tryFormats = "%d/%m/%Y")
df$yr <- as.numeric(format(df$adm, "%Y"))
df <- df[!is.na(df$PDX),]
df |> group_by(yr) |> summarise(count = n(), totalPIM3 = sum(prob_death), meanPIM3 = mean(prob_death))
