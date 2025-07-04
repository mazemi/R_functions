##################################################
# this function generate public data set for JMMI.
# input parameters: session and tool path
# other required data:
# median data, clean data, datamerge
# and admin codes and labels
# 
# version: 1.0
# date: 12 May 2025
##################################################

generate_public_data <- function(session, tool_path){
  
  # just for test
  # tool_path <- "input/questionnaire/JMMI_Tool_v8.xlsx"
  # session <-"JMMI_R60_Jun25"
  
  wb <- loadWorkbook("./public_dataset/misc_data/public_dt_template.xlsx")
  
  YEAR <- paste0("20",str_extract(session, "\\d+$"))
  MONTH <- str_match(session, "^[^_]*_[^_]*_([^_]{3})")[, 2]
  ROUND <- str_extract(session, "(?<=_R)\\d+")
  
  ## add admin labels
  lookup_admin <- read.csv("./public_dataset/misc_data/dist_prov_region.csv", stringsAsFactors = FALSE)
  survey_sheet <- read.xlsx(tool_path, sheet = "survey")
  survey_sheet <- survey_sheet %>% select(type,name, `label::English`, `label::Dari`, `label::Pashtu`)
  choice_sheet <- read.xlsx(tool_path, sheet = "choices") %>% select(list_name, name, `label::English`)
  
  # input data
  clean_df_path <- list.files(path = "./input/data/", pattern = ".xlsx$", full.names = TRUE)
  clean_df <- read.xlsx(clean_df_path[1]) 
  
  # date_period <- clean_df$date
  date_period <- as.Date(clean_df$date, origin = "1899-12-30")
  
  data_count <- nrow(clean_df)
  dict_count <- length(unique(clean_df$afg_dist))
  prov_count <- length(unique(clean_df$afg_prov))
  partners_count <- length(unique(clean_df$partner))
  
  clean_df <- clean_df %>% select(partner, afg_prov)
  
  file_path <- list.files(path = "./results/", pattern = "^median.*\\.xlsx$", full.names = TRUE)
  median_df <- read.xlsx(file_path[1], sheet = 1) 
  meb_df <- read.xlsx(file_path[1], sheet = 3)  
  
  ## helper look up function for getting admin labels
  exact_lookup <- function(df, lookup_admin, key_col_df, key_col_lookup, value_col_lookup) {
    sapply(df[[key_col_df]], function(key) {
      match_row <- which(lookup_admin[[key_col_lookup]] == key)
      if (length(match_row) > 0) {
        return(lookup_admin[[value_col_lookup]][match_row[1]])
      } else {
        return(NA)
      }
    })
  }
  
  # load datamerge
  dm_file_path <- list.files("./results/", pattern = "^datamerge.*\\.csv$", full.names = TRUE)[1]
  dm <- read.csv(dm_file_path)
  
  cols_to_select <- c(
    "level",
    "disaggregation",
    "samplesize",
    "food_suplier_change..value..",
    "food_supplier_loc..value..",
    "nfi_supplier_change..value..",
    "nfi_supplier_loc..value..",
    "market_credit_month..value..",
    "market_credit_who..value..",
    "usd_afn_exchange..value..",
    "financial_services..value..",
    "access_security..value..",
    "modality..value.."
  )
  
  ## add readme info
  # Append month and year in the Readme title
  title1 <- "AFGHANISTAN | REACH Initiative and Cash and Voucher Working Group (CVWG)"
  title2 <- "Joint Market Monitoring Initiative (JMMI)"
  title3 <- "DATASET"
  data_collection_month <- paste0(MONTH, " ", YEAR)
  data_collection_period <- paste0("(round ", ROUND , ")")
  new_title <- paste(c(title1, title2, title3, data_collection_month), collapse = "\n")
  
  min_date <- min(date_period, na.rm = TRUE)
  max_date <- max(date_period, na.rm = TRUE)
  
  choice_sheet_prov <- choice_sheet %>% 
    filter(list_name =="province_list") %>% 
    select(-list_name, province_name = `label::English`)
  
  choice_sheet_partners <- choice_sheet %>% 
    filter(list_name =="partner") %>% 
    select(-list_name, partner_name = `label::English`)
  
  clean_df <- clean_df %>% inner_join(choice_sheet_prov, by= c("afg_prov"="name"))
  clean_df <- clean_df %>% inner_join(choice_sheet_partners, by= c("partner"="name"))
  clean_df <- clean_df %>% select(-afg_prov)
  
  partners <- unique(clean_df$partner_name)
  provinces <- unique(clean_df$province_name)
  
  provinces_str <- paste(provinces, collapse = ", ")
  provinces_str <- paste0("This assessment covered markets sampled by partners nationwide. This includes markets in ",
                          prov_count , " of 34 provinces and ", dict_count , 
                          " out of 419 districts in Afghanistan, the provinces are as following: " ,
                          provinces_str)
  
  partners_str <- paste(partners, collapse = ", ")
  partners_str <- paste0("The JMMI data collection was conducted by ", partners_count, 
                         " organizations and agencies: ",partners_str)
  
  
  ##  add district level MEB and price
  dist1 <- median_df %>% filter(level == "district") %>% select(-c(period, level))
  meb1 <- meb_df %>% filter(level == "district") %>% select(admin_code, food_basket_AFN, meb_AFN)
  dist1 <- inner_join(meb1, dist1)
  dist1 <- inner_join(lookup_admin,dist1, by=c("district_code"="admin_code"))
  dist1 <- dist1 %>% select(-c(region_code, province_code))
  dist1 <- dist1 %>% select(region_name, province_name, district_name, district_code, everything())
  
  ##  add provincial level MEB
  meb2 <- meb_df %>% filter(level == "province") %>% select(admin_code, food_basket_AFN, meb_AFN)
  lookup_admin_prov <- lookup_admin %>% select(region_name, province_code, province_name)
  lookup_admin_prov <- lookup_admin_prov[!duplicated(lookup_admin_prov$province_code), ]
  prov1 <- inner_join(lookup_admin_prov,meb2, by=c("province_code"="admin_code"))
  prov1 <- prov1 %>% select(region_name, province_name, everything())
  
  
  # Get matching column names for each cols_to_select
  matched_cols_list <- lapply(cols_to_select, function(p) {
    names(dm)[startsWith(names(dm), p)]
  })
  
  matched_cols <- unlist(matched_cols_list)
  dm <- dm[, matched_cols]
  
  merge_sizes <- sapply(matched_cols_list, length)
  merge_sizes <- merge_sizes[-(1:3)]
  merge_sizes <- c(4, merge_sizes)
  
  merge_labels <- c(
    "disaggregation",
    "Reported change in the number of food items suppliers",
    "Reported location of food items suppliers",
    "Reported change in the number of NFIs suppliers",
    "Reported location on NFIs suppliers",
    "Traders' use of credit",
    "Traders' use of credit",
    "US-AFN exchange within the marketplace",
    "Financial Service Providers (FSPs)",
    "Customers' reported security constraints in accessing the marketplace (overall, and by type)",
    "Payment modalities accepted by the traders"
  )
  
  ## regional level indicators
  region_admin <- lookup_admin %>% select(region_code, region_name)
  region_admin <- unique(region_admin)
  reg_dm <- dm %>% filter(level %in% c("No_disagregation","afg_region"))
  reg_dm <- reg_dm %>% left_join(region_admin, by= c("disaggregation" = "region_code"))
  reg_dm <- reg_dm %>% select(level, region_name, region_code = disaggregation, everything())
  reg_dm[1, "level"] <- "Afghanistal"
  reg_dm[1, "region_code"] <- NA
  reg_dm$level[reg_dm$level == "afg_region"] <- "Region"
  
  ## provincial level indicators
  province_admin <- lookup_admin %>% select(province_code, province_name)
  province_admin <- unique(province_admin)
  prov_dm <- dm %>% filter(level=="afg_prov")
  prov_dm <- prov_dm %>% left_join(province_admin, by= c("disaggregation" = "province_code"))
  prov_dm <- prov_dm %>% select(level, province_name, province_code = disaggregation, everything())
  
  prov_dm$level <- exact_lookup(prov_dm, lookup_admin, "province_code", "province_code", "region_name")
  prov_dm <- dplyr::rename(prov_dm, region = level)
  
  ## district level indicators
  disct_admin <- lookup_admin %>% select(district_code, district_name)
  disct_admin <- unique(disct_admin)
  dist_dm <- dm %>% filter(level=="afg_dist")
  dist_dm <- dist_dm %>% left_join(disct_admin, by= c("disaggregation" = "district_code"))
  dist_dm <- dist_dm %>% select(level, district_name, district_code = disaggregation, everything())
  
  dist_dm$level <- exact_lookup(dist_dm, lookup_admin, "district_code", "district_code", "province_name")
  dist_dm <- dplyr::rename(dist_dm, province = level)
  
  ## survey sheet of the kobo tool
  questions <- read.xlsx(tool_path, sheet = "survey")
  questions <- questions %>% select(type, name, `label::English`, `label::Dari`, `label::Pashtu`)
  
  # writing data to the excel workbook
  writeData(wb, sheet = "README", x = new_title, startRow = 1, startCol = 1)
  writeData(wb, sheet = "README", x = (paste0(min_date, " to ", max_date, " ", data_collection_period)),, startCol = 2, startRow = 13)
  writeData(wb, sheet = "README", x = data_count, startCol = 2, startRow = 14)
  writeData(wb, sheet = "README", x = provinces_str , startCol = 2, startRow = 15)
  writeData(wb, sheet = "README", x = partners_str, startCol = 2, startRow = 16)
  
  addWorksheet(wb, "MEB-FB & Price in AFN- District")
  writeData(wb, sheet = "MEB-FB & Price in AFN- District", x = dist1)
  
  addWorksheet(wb, "MEB & Food basket - Province")
  writeData(wb, sheet = "MEB & Food basket - Province", x = prov1)
  
  addWorksheet(wb, "Data analysis - District")
  addWorksheet(wb, "Data analysis - Province")
  addWorksheet(wb, "Data analysis - Region")
  
  addWorksheet(wb, "survey")
  writeData(wb, sheet = "survey", x = questions)
  
  
  sheet_names <- c("Data analysis - Region", 
                   "Data analysis - Province", 
                   "Data analysis - District")
  
  for (sheet in sheet_names) {
    col_start <- 1
    for (i in seq_along(merge_labels)) {
      size <- merge_sizes[i]
      col_end <- col_start + size - 1
      mergeCells(wb, sheet = sheet, cols = col_start:col_end, rows = 1)
      writeData(wb, sheet = sheet, x = merge_labels[i], startCol = col_start, startRow = 1)
      col_start <- col_end + 1
    }
  }
  
  writeData(wb, sheet = "Data analysis - Region", x = reg_dm, startCol = 1 , startRow = 2)
  writeData(wb, sheet = "Data analysis - Region", x = "region", startCol = 2, startRow = 2)
  
  writeData(wb, sheet = "Data analysis - Province", x = prov_dm, startCol = 1 , startRow = 2)
  writeData(wb, sheet = "Data analysis - Province", x = "province", startCol = 2, startRow = 2)
  
  writeData(wb, sheet = "Data analysis - District", x = dist_dm, startCol = 1 , startRow = 2)
  writeData(wb, sheet = "Data analysis - District", x = "district", startCol = 2, startRow = 2)
  
  modifyBaseFont(wb, fontSize = 10, fontName = "Calibri")
  
  # Style: all borders
  border_style <- createStyle(border = "TopBottom", borderColour = "#cccaca")
  
  # Style: all vertical border
  vertical_style <- createStyle(
    border = "Right",              
    borderColour = "#403f3e",      
    borderStyle = "medium"              
  )
  
  # Style: bottom line border
  bottomline_style <- createStyle(
    border = "Bottom",              
    borderColour = "#403f3e",      
    borderStyle = "medium"              
  )
  
  # Style: first row simple
  header_style_simple <- createStyle(
    halign = "center", valign = "center", fgFill = "#b8b8b6", 
    border = "TopBottomLeftRight", wrapText = TRUE,
  )
  
  # Style: first row
  header_style <- createStyle(
    halign = "center", valign = "center", fgFill = "#b8b8b6", 
    textDecoration = "bold", border = "TopBottomLeftRight", 
    borderColour = "#4f4f4d", wrapText = TRUE, borderStyle = "medium"
  )
  
  # Style: second row
  second_row_style <- createStyle(
    halign = "left", fgFill = "#cfcfcc",
    border = "TopBottomLeftRight", borderColour = "#4f4f4d"
  )
  
  # Style: add percentage
  percentStyle <- createStyle(numFmt = '0"%"')  
  
  dd <- "MEB-FB & Price in AFN- District"
  str_length(dd)
  
  # apply styles
  addStyle(wb, "MEB-FB & Price in AFN- District", style = border_style, rows = 1:(nrow(dist1) + 1), cols = 1:ncol(dist1), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB-FB & Price in AFN- District", style = header_style_simple, rows = 1, cols = 1:ncol(dist1), gridExpand = TRUE)
  addStyle(wb, "MEB-FB & Price in AFN- District", style = vertical_style, rows = 1:(nrow(dist1) + 1), cols = 4, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB-FB & Price in AFN- District", style = vertical_style, rows = 1:(nrow(dist1) + 1), cols = 6, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB-FB & Price in AFN- District", style = vertical_style, rows = 1:(nrow(dist1) + 1), cols = ncol(dist1), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB-FB & Price in AFN- District", style = bottomline_style, rows = (nrow(dist1) + 1), cols = 1:ncol(dist1), gridExpand = TRUE, stack = TRUE)
  
  setColWidths(wb, "MEB-FB & Price in AFN- District", cols = 1:ncol(dist1), widths = 16)
  setColWidths(wb, "MEB-FB & Price in AFN- District", cols = 3, widths = 25)
  
  addStyle(wb, "MEB & Food basket - Province", style = border_style, rows = 1:(nrow(prov1) + 1), cols = 1:ncol(prov1), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB & Food basket - Province", style = header_style_simple, rows = 1, cols = 1:ncol(prov1), gridExpand = TRUE)
  addStyle(wb, "MEB & Food basket - Province", style = vertical_style, rows = 1:(nrow(prov1) + 1), cols = c(3,5), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "MEB & Food basket - Province", style = bottomline_style, rows = (nrow(prov1) + 1), cols = 1:ncol(prov1), gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, "MEB & Food basket - Province", cols = 1:5, widths = 17)
  
  addStyle(wb, "Data analysis - District", style = border_style, rows = 1:(nrow(dist_dm) + 2), cols = 1:ncol(dist_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - District", style = header_style, rows = 1, cols = 1:ncol(dist_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - District", style = second_row_style, rows = 2, cols = 1:ncol(dist_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - District", style = vertical_style, rows = 1:(nrow(dist_dm) + 2), cols = 4, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - District", style = vertical_style, rows = 1:(nrow(dist_dm) + 2), cols = ncol(dist_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - District", style = bottomline_style, rows = (nrow(dist_dm) + 2), cols = 1:ncol(dist_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, sheet = "Data analysis - District", style = percentStyle, rows = 3:(nrow(dist_dm) + 2), cols = 5:ncol(dist_dm), gridExpand = TRUE, stack = TRUE)
  
  setRowHeights(wb, "Data analysis - District", rows = 1, heights = 30)
  setColWidths(wb, "Data analysis - District", cols = 1, widths = 20)
  setColWidths(wb, "Data analysis - District", cols = 2, widths = 25)
  setColWidths(wb, "Data analysis - District", cols = 3, widths = 14)
  
  addStyle(wb, "Data analysis - Province", style = border_style, rows = 1:(nrow(prov_dm) + 2), cols = 1:ncol(prov_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Province", style = header_style, rows = 1, cols = 1:ncol(prov_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - Province", style = second_row_style, rows = 2, cols = 1:ncol(prov_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - Province", style = vertical_style, rows = 1:(nrow(prov_dm) + 2), cols = 4, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Province", style = vertical_style, rows = 1:(nrow(prov_dm) + 2), cols = ncol(prov_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Province", style = bottomline_style, rows = (nrow(prov_dm) + 2), cols = 1:ncol(prov_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, sheet = "Data analysis - Province", style = percentStyle, rows = 3:(nrow(prov_dm) + 2), cols = 5:ncol(prov_dm), gridExpand = TRUE, stack = TRUE)
  
  setRowHeights(wb, "Data analysis - Province", rows = 1, heights = 30)
  setColWidths(wb, "Data analysis - Province", cols = 1, widths = 20)
  setColWidths(wb, "Data analysis - Province", cols = 2, widths = 25)
  setColWidths(wb, "Data analysis - Province", cols = 3, widths = 14)
  
  addStyle(wb, "Data analysis - Region", style = border_style, rows = 1:(nrow(reg_dm) + 2), cols = 1:ncol(reg_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Region", style = header_style, rows = 1, cols = 1:ncol(reg_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - Region", style = second_row_style, rows = 2, cols = 1:ncol(reg_dm), gridExpand = TRUE)
  addStyle(wb, "Data analysis - Region", style = vertical_style, rows = 1:(nrow(reg_dm) + 2), cols = 4, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Region", style = vertical_style, rows = 1:(nrow(reg_dm) + 2), cols = ncol(reg_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Data analysis - Region", style = bottomline_style, rows = (nrow(reg_dm) + 2), cols = 1:ncol(reg_dm), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, sheet = "Data analysis - Region", style = percentStyle, rows = 3:(nrow(reg_dm) + 2), cols = 5:ncol(reg_dm), gridExpand = TRUE, stack = TRUE)
  
  setRowHeights(wb, "Data analysis - Region", rows = 1, heights = 30)
  setColWidths(wb, "Data analysis - Region", cols = 1, widths = 20)
  setColWidths(wb, "Data analysis - Region", cols = 2, widths = 25)
  setColWidths(wb, "Data analysis - Region", cols = 3, widths = 14)
  
  addStyle(wb, "survey", style = border_style, rows = 1:(nrow(questions) + 1), cols = 1:ncol(questions), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "survey", style = header_style_simple, rows = 1, cols = 1:ncol(questions), gridExpand = TRUE)
  setColWidths(wb, "survey", cols = 1:2, widths = 30)
  setColWidths(wb, "survey", cols = 3:5, widths = 40)
  
  saveWorkbook(wb, file = paste0("./public_dataset/output_data/REACH_AFG_CVWG_JMMI_Dataset_", MONTH, YEAR, ".xlsx"), overwrite = TRUE)
  cat("Public dataset has ben generated.")
}


