#!/usr/bin/env Rscript

###############################################################################
# AUTHOR : OLABIYI ADEREMI OBAYOMI
# DESCRIPTION: A script to write to perform pairwise ANCOM BC1 diffrential abundance testing.
# E-mail: obadbotanist@yahoo.com
# Created: November 2024
# example: Rscript pairwise_ancombc1.R \
#                  --metadata-table 'mapping/GLDS-487_amplicon_v1_runsheet.csv' \
#                  --feature-table 'data/counts_GLAmpSeq.tsv' \
#                  --taxonomy-table 'data/taxonomy_GLAmpSeq.tsv' \
#                  --group 'groups' \
#                  --samples-column 'Sample Name' \
#                  --cpus 5
###############################################################################

library(optparse)
library(glue)


######## -------- Get input variables from the command line ----##############

version <- 1.0 

# Input options 
option_list <- list(
  
  make_option(c("-m", "--metadata-table"), type="character", default=NULL, 
              help="path to a comma separated samples metadata file with the 
              group/treatment to be analyzed.",
              metavar="path"),
  
  make_option(c("-f", "--feature-table"), type="character", default=NULL, 
              help="path to a tab separated samples feature table 
              i.e. ASV or OTU table.",
              metavar="path"),
  
  make_option(c("-t", "--taxonomy-table"), type="character", default=NULL, 
              help="path to feature taxonomy table i.e. ASV or OTU taxonomy table.",
              metavar="path"),
  
  make_option(c("-o", "--output-prefix"), type="character", default="", 
              help="Unique name to tag onto output files. Default: empty string.",
              metavar=""),
  
  make_option(c("-y", "--assay-suffix"), type="character", default="_GLAmpSeq", 
              help="Genelab assay suffix.", metavar="GLAmpSeq"),
  
  make_option(c("-g", "--group"), type="character", default="groups", 
              help="Column in metadata to be analyzed",
              metavar="groups"),
  
  make_option(c("-s", "--samples-column"), type="character", default="Sample Name", 
              help="Column in metadata containing the sample names in the feature table",
              metavar="Sample Name"),
  
  make_option(c("-a", "--feature-type"), type="character", default="ASV", 
              help="What feature counts are in the feature table i.e ASV, OTU etc.
              This name will be used to name the feature column in the final table.",
              metavar="ASV"),
  
  make_option(c("-r", "--target-region"), type="character", default="16S", 
              help="Amplicon target region. Options are either 16S, 18S or ITS \
              Default: 16S",
              metavar="16S"),
  
  make_option(c("-c", "--cpus"), type="numeric", default=1, 
              help="Number of cpus to us for parallel processing.",
              metavar="1"),
  
  make_option(c("-p", "--prevalence-cutoff"), type="numeric", default=0.15, 
              help="a numerical fraction between 0 and 1. Taxa with prevalences
              (the proportion of samples in which the taxon is present) less 
              than --prevalence-cutoff will be excluded in the analysis. 
              Default is 0.15, i.e. exclude taxa / features that are not present
              in at least 15% of the samples.",
              metavar="0.15"),
  
  make_option(c("-l", "--library-cutoff"), type="numeric", default=100, 
              help="a numerical threshold for filtering samples based on library
              sizes. Samples with library sizes less than lib_cut will be 
              excluded in the analysis. Default is 100. 
              if you do not want to discard any sample then set to 0.",
              metavar="100"),
  
  make_option(c("--version"), action = "store_true", type="logical", 
              default=FALSE,
              help="Print out version number and exit.", metavar = "boolean")
)




opt_parser <- OptionParser(
  option_list=option_list,
  usage = "Rscript %prog \\
                  --metadata-table 'mapping/GLDS-487_amplicon_v1_runsheet.csv' \\
                  --feature-table 'data/counts_GLAmpSeq.tsv' \\
                  --taxonomy-table 'data/taxonomy_GLAmpSeq.tsv' \\
                  --group 'groups' \\
                  --samples-column 'Sample Name' \\
                  --cpus 5",
  description = paste("Author: Olabiyi Aderemi Obayomi",
                      "\nEmail: olabiyi.a.obayomi@nasa.gov",
                      "\n A script to perform pairwise ANCOMBC1.",
                      "\nIt outputs a table of differential abundance statistics",
                      ", abundance volcano and boxplots.",
                      sep="")
)


opt <- parse_args(opt_parser)

# print(opt)
# stop()


if (opt$version) {
  cat("pairwise_ancombc1.R version: ", version, "\n")
  options_tmp <- options(show.error.messages=FALSE)
  on.exit(options(options_tmp))
  stop()
}



if(is.null(opt[["metadata-table"]])) {
  stop("Path to a metadata file must be set.")
}

if(is.null(opt[["feature-table"]])) {
  stop("Path to a feature table e.g. ASV table file must be set.")
}


if(is.null(opt[["taxonomy-table"]])) {
  stop("Path to a metadata file must be set.")
}

if(opt[["group"]] == "groups") {
  cat("ANCOMBC will be run on the default 'groups' column 
      since it was not set by the user")
}

if(opt[["samples-column"]] == "Sample Name") {
  cat("I will assume that the sample names are 
      in the column named 'Sample Name' ")
}



library(ANCOMBC)
library(DescTools)
library(taxize)
library(glue)
library(mia)
library(phyloseq)
library(utils)
library(tools)
library(patchwork)
library(ggrepel)
library(tidyverse)


# ---------------------------- Functions ------------------------------------- #

process_taxonomy <- function(taxonomy, prefix='\\w__') {
  #function to process a metaphlan2 taxonopmy assigment table
  #1. ~ file_path is a string specifying the taxonomic assignment file name
  #2 prefix ~ is a regular expression specifying the characters to remove
  # from the taxon names  '\\w__'  for greengenes and 'D_\\d__' for SILVA
  
  #taxon_levels <- c("kingdom","phylum","class","order",
  #                  "family","genus","species", "strain")
  
  taxonomy <- apply(X = taxonomy, MARGIN = 2, FUN = as.character) 
  
  #taxonomy[,'species'] <- paste(taxonomy[,'genus'],taxonomy[,'species'])
  # replace NAa with Other and delete the D_num__ prefix from the taxonomy names
  for (rank in colnames(taxonomy)) {
    #delete the taxonomy prefix
    taxonomy[,rank] <- gsub(pattern = prefix, x = taxonomy[, rank],
                            replacement = '')
    indices <- which(is.na(taxonomy[,rank]))
    taxonomy[indices, rank] <- rep(x = "Other", times=length(indices)) 
    #replace empty cell
    indices <- which(taxonomy[,rank] == "")
    taxonomy[indices,rank] <- rep(x = "Other", times=length(indices))
  }
  taxonomy <- apply(X = taxonomy,MARGIN = 2,
                    FUN =  gsub,pattern = "_",replacement = " ") %>% 
    as.data.frame(stringAsfactor=F)
  return(taxonomy)
}



# Function for format a taxonomy assignment table by appending suffix
# to a known name
format_taxonomy_table <- function(taxonomy=taxonomy.m,stringToReplace="Other",
                                  suffix=";Other") {
  
  for (taxa_index in seq_along(taxonomy)) {
    #indices <- which(taxonomy[,taxa_index] == stringToReplace)
    
    indices <- grep(x = taxonomy[,taxa_index], pattern = stringToReplace)
    
    taxonomy[indices,taxa_index] <- 
      paste0(taxonomy[indices,taxa_index-1],
             rep(x = suffix, times=length(indices)))
    
  }
  return(taxonomy)
}


fix_names<- function(taxonomy,stringToReplace,suffix){
  #1~ taxonomy is a taxonomy dataframe with taxonomy ranks as column names
  #2~ stringToReplace is a vector of regex strings specifying what to replace
  #3~ suffix is a string specifying the replacement value
  
  
  for(index in seq_along(stringToReplace)){
    taxonomy <- format_taxonomy_table(taxonomy = taxonomy,
                                      stringToReplace=stringToReplace[index], 
                                      suffix=suffix[index])
  }
  return(taxonomy)
}



# A function to generate taxon level count matrix based on a taxonomy table and
# an existing feature table
# make_feature_table <- function(count_matrix,taxonomy,
#                                taxon_level, samples2keep=NULL){
#   
#   # EAMPLE:
#   # make_feature_table(count_matrix = feature_counts_matrix,
#   #                    taxonomy = taxonomy_table, taxon_level = "Phylum")
#   
#   feature_counts_df <- data.frame(taxon_level=taxonomy[,taxon_level],
#                                   count_matrix, check.names = FALSE, 
#                                   stringsAsFactors = FALSE)
#   
#   feature_counts_df <- aggregate(.~taxon_level,data = feature_counts_df,
#                                  FUN = sum)
#   rownames(feature_counts_df) <- feature_counts_df[,"taxon_level"]
#   feature_table <- feature_counts_df[,-1]
#   # Retain only taxa found in at least one sample
#   taxa2keep <- rowSums(feature_table) > 0
#   feature_table <- feature_table[taxa2keep,]
#   
#   if(!is.null(samples2keep)){
#     feature_table <- feature_table[,samples2keep]
#     # Retain only taxa found in at least one sample
#     taxa2keep <- rowSums(feature_table) > 0
#     feature_table <- feature_table[taxa2keep,]
#   }
#   
#   return(feature_table)
# }

taxize_options(ncbi_sleep = 0.8)
# A function to retrieve the NCBI taxonomy id for a given taxonomy name
get_ncbi_ids <- function(taxonomy, target_region){
  
  if(target_region == "ITS"){
    search_string <- "fungi"
  }else if(target_region == "18S"){
    search_string <- "eukaryote"
  }else{
    search_string <- "bacteria"
  }
  
  uid <- get_uid(taxonomy, division_filter = search_string)
  
  tax_ids <- uid[1:length(uid)]
  
  return(tax_ids)
  
}



publication_format <- theme_bw() +
  theme(panel.grid = element_blank()) +
  theme(axis.ticks.length=unit(-0.15, "cm"),
        axis.text.x=element_text(margin=ggplot2::margin(t=0.5,r=0,b=0,l=0,unit ="cm")),
        axis.text.y=element_text(margin=ggplot2::margin(t=0,r=0.5,b=0,l=0,unit ="cm")), 
        axis.title = element_text(size = 18,face ='bold.italic', color = 'black'), 
        axis.text = element_text(size = 16,face ='bold', color = 'black'),
        legend.position = 'right', 
        legend.title = element_text(size = 15,face ='bold', color = 'black'),
        legend.text = element_text(size = 14,face ='bold', color = 'black'),
        strip.text =  element_text(size = 14,face ='bold', color = 'black'))


# ------ Collecting the required input variables ---------- #

# Group in metadata to analyze
group <- opt[["group"]]  # "groups"
samples_column <- opt[["samples-column"]] # "Sample Name"
threads <- opt[["cpus"]] # 8
metadata_file <- opt[["metadata-table"]]
taxonomy_file <-  opt[["taxonomy-table"]]
feature_table_file <- opt[["feature-table"]]
feature <- opt[["feature-type"]]   # "ASV"
target_region <- opt[["target-region"]] # 16S
output_prefix <- opt[["output-prefix"]]
assay_suffix <- opt[["assay-suffix"]]

# taxon / ASV prevalence cutoff
prevalence_cutoff <- opt[["prevalence-cutoff"]] # 0.15 (15%)
# sample / library read count cutoff
library_cutoff <- opt[["library-cutoff"]]  # 100
diff_abund_out_dir <- "differential_abundance/ancombc1/"
if(!dir.exists(diff_abund_out_dir)) dir.create(diff_abund_out_dir, recursive = TRUE)


# ------------------------ Read metadata ---------------------------------- #
metadata <- read_csv(metadata_file)  %>% as.data.frame()
rownames(metadata) <- metadata[[samples_column]]



# -------------------------- Read Feature table  -------------------------- #
feature_table <- read_delim(file = feature_table_file) %>% as.data.frame()

# Set the feature id column as the row names of the feature table
# This assumes that the first column contains the feature ids e.g. ASV ID 
rownames(feature_table) <- feature_table[,1]
feature_names <- feature_table[,1]
# Drop the feature column
feature_table <- feature_table[, -1] %>% as.data.frame()
rownames(feature_table) <-  feature_names


# ------------------------ Read Taxonomy table ---------------------------- #
taxonomy <-  read_delim(file = taxonomy_file) %>% as.data.frame()
# Set the feature id column as the row names of the taxonomy table
# This assumes that the first column contains the feature ids e.g. ASV ID 
rownames(taxonomy) <- taxonomy[,1]
taxonomy_table  <- taxonomy[, -1]
feature_names <- rownames(taxonomy_table)
taxonomy_table  <- process_taxonomy(taxonomy_table)
rownames(taxonomy_table) <- feature_names

print(glue("There are {sum(taxonomy_table$phylum == 'Other')} features without 
           taxonomy assignments. Dropping them ..."))

# Dropping features that couldn't be assigned taxonomy
taxonomy_table <- taxonomy_table[-which(taxonomy_table$phylum == 'Other'),]

# Handle case where no domain was assigned but a phylum wasn't.
if(all(is.na(taxonomy$domain))){
  
  if(target_region == "ITS"){
    
    taxonomy_table$domain <- "Fungi"
    
  }else if(target_region == "18S"){
    
    taxonomy_table$domain <- "Eukaryotes"
    
  }else{
    
    taxonomy_table$domain <- "Bacteria"
  }
  
}

# Removing Chloroplast and Mitochondria Organelle DNA contamination
asvs2drop <- taxonomy_table %>%
  unite(col="taxonomy",domain:species) %>%
  filter(str_detect(taxonomy, "[Cc]hloroplast|[Mn]itochondria")) %>%
  row.names()
taxonomy_table <- taxonomy_table[!(rownames(taxonomy_table) %in% asvs2drop),]


# Get long asv taxonomy names and clean
species <- taxonomy_table %>%
  unite(species,domain:species,sep = ";") %>% # Generalize this line -------- 
pull %>% str_replace_all("Other", "_")

taxonomy_table <- fix_names(taxonomy_table, "Other", ";_")

taxonomy_table[,"species"] <- species


# ---------------------- Subset tables ------------------------------------- #

# Get features common to the taxonomy and feature table 
common_ids <- intersect(rownames(feature_table), rownames(taxonomy_table))

# Subset the feature and taxonomy tables to contain 
# only features found in both table
feature_table <- feature_table[common_ids,]
taxonomy_table <- taxonomy_table[common_ids,]

# -------------------------Prepare feature tables -------------------------- #
# taxon_levels <- colnames(taxonomy_table)
# names(taxon_levels) <- taxon_levels
# taxon_tables <- map(.x = taxon_levels,
#                     .f = make_feature_table,
#                     count_matrix = feature_table, 
#                     taxonomy = taxonomy_table)


# Create phyloseq object
ps <- phyloseq(otu_table(feature_table, taxa_are_rows = TRUE),
               sample_data(metadata),
               tax_table(as.matrix(taxonomy_table)))

# Convert phyloseq to tree summarized experiment object
tse <-  mia::makeTreeSummarizedExperimentFromPhyloseq(ps)


# Get unique group comparison as a matrix
pairwise_comp.m <- utils::combn(metadata[,group] %>% unique, 2)
pairwise_comp_df <- pairwise_comp.m %>% as.data.frame 

colnames(pairwise_comp_df) <- map_chr(pairwise_comp_df,
                                      \(col) str_c(col, collapse = "v"))
comparisons <- colnames(pairwise_comp_df)
names(comparisons) <- comparisons


message("Running ANCOMBC1....")
set.seed(123)
final_results_bc1  <- map(pairwise_comp_df, function(col){
  
  group1 <- col[1]
  group2 <- col[2]
  
  tse_sub <-  tse[, tse[[group]] %in% c(group1, group2)]
  
  # Note that by default, levels of a categorical variable in R are sorted 
  # alphabetically. 
  # Changing the reference group by reordering the factor levels
  tse_sub[[group]] <- factor(tse_sub[[group]] , levels = c(group1, group2))
  
  # data - input data. TreeSummarizedExperiment or Phyloseq object
  # assay_name - name of count table in the input data object.
  # tax_level - taxonomy level for aggregation and analysis
  # prv_cut - prevalence cut-off. proportion of samples in which taxon is present.
  # lib_cut - a numerical threshold for filtering samples based on library sizes.
  # p_adj_method - p-value adjustment method for multiple comparisons
  # struc_zero - should group-wise rare taxa be detected
  # neg_lb - whether to classify a taxon as a structural zero using its asymptotic lower bound. i.e.the best the algorithm can possibly achieve 
  # group - name of the group variable in metadata. Only important you'd like to perform global test  can be set to NULL.
  # alpha - significance level
  # n_cl - number of processes to run in parallel
  # global - should a global test be performed to detect significant differences between at least 2 groups (ANOVA-like comparison) 
  # tol - iteration convergence tolerance for the E-M algorithm.
  # max_iter - max iteration 
  # formula - fixed effects formula
  # conserve - should a conservative variance estimator be used for the test statistic? 
  # it is recommended to set to TRUE if your sample size is small and the number of expected differentially abundant taxa is large.
  
  out <-  ancombc(data = tse_sub, assay_name = "counts", 
                  tax_level = NULL, phyloseq = NULL, 
                  formula = group, 
                  p_adj_method = "fdr", prv_cut = prevalence_cutoff,
                  lib_cut = library_cutoff, 
                  group = group, struc_zero = TRUE, neg_lb = TRUE, tol = 1e-5, 
                  max_iter = 100, conserve = TRUE, alpha = 0.05, global = FALSE,
                  n_cl = threads, verbose = TRUE)
  
  # ------ Set data frame names ---------# 
  # LFC 
  lfc <- out$res$lfc %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>% 
    set_names(
      c("taxon",
        glue("logFC_({group2})v({group1})"))
    )
  
  # SE
  se <- out$res$se %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>%
    set_names(
      c("taxon",
        glue("lfcSE_({group2})v({group1})"))
    )
  
  # W    
  W <- out$res$W %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>%
    set_names(
      c("taxon",
        glue("Wstat_({group2})v({group1})"))
    )
  
  # p_val
  p_val <- out$res$p_val %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>%
    set_names(
      c("taxon",
        glue("pvalue_({group2})v({group1})"))
    )
  
  # q_val
  q_val <- out$res$q_val %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>% 
    set_names(
      c("taxon",
        glue("qvalue_({group2})v({group1})"))
    )
  
  
  # Diff_abn
  diff_abn <- out$res$diff_abn %>%
    as.data.frame() %>% 
    select(-contains("Intercept")) %>%
    set_names(
      c("taxon",
        glue("diff_({group2})v({group1})"))
    )
  
  
  res <-lfc %>%
    left_join(se) %>%
    left_join(W) %>% 
    left_join(p_val)  %>% 
    left_join(q_val) %>% 
    left_join(diff_abn)
  
  
  return(res)
  
})



# Create merged stats pairwise dataframe
# initialize the merged stats dataframe to contain the taxon column for joining
merged_stats_df <- final_results_bc1[[names(final_results_bc1)[1]]] %>%
  as.data.frame() %>% select(taxon)

walk(comparisons[names(final_results_bc1)], .f = function(comparison){
  
  df <-  final_results_bc1[[comparison]] %>% as.data.frame()
  
  merged_stats_df <<- merged_stats_df %>%
    dplyr::full_join(df, by = join_by("taxon"))
  
})

# Sort ASVs in ascending order
merged_stats_df <- merged_stats_df %>% 
  rename(!!feature := taxon) %>%
  mutate(!!feature := SortMixed(!!sym(feature)))



comp_names <- merged_stats_df %>% 
  select(starts_with("logFC")) %>%
  colnames() %>% str_remove_all("logFC_")
names(comp_names) <- comp_names

message("Making volcano plots...")
# -------------- Make volcano plots ------------------ #
volcano_plots <- map(comp_names, function(comparison){
  
  comp_col  <- c(
    glue("logFC_{comparison}"),
    glue("lfcSE_{comparison}"),
    glue("Wstat_{comparison}"),
    glue("pvalue_{comparison}"),
    glue("qvalue_{comparison}"),
    glue("diff_{comparison}")
  )
  
  
  sub_res_df <- merged_stats_df %>% 
    select(!!feature, all_of(comp_col)) %>% drop_na()
  colnames(sub_res_df) <- str_replace_all(colnames(sub_res_df),
                                          pattern = "(.+)_.+", 
                                          replacement = "\\1")
  
  p <- ggplot(sub_res_df, aes(x=logFC, y=-log10(pvalue), color=diff, label=!!sym(feature))) +
    geom_point(size=4) +
    scale_color_manual(values=c("TRUE"="red", "FALSE"="black")) +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
    ggrepel::geom_text_repel() + 
    labs(x="logFC", y="-log10(Pvalue)", 
         title = comparison, color="Significant") + publication_format
  
  ggsave(filename = glue("{output_prefix}{comparison}_volcano{assay_suffix}.png"), plot = p, device = "png",
         width = 6, height = 8, units = "in", dpi = 300, path = diff_abund_out_dir)
  
  return(p)
})




number_of_columns <- 2
number_of_rows = ceiling(length(comp_names) / number_of_columns)
fig_height = 7.5 * number_of_rows

p <- wrap_plots(volcano_plots, ncol = 2)
#  Try to combine all the volcano plots in one figure
try(
ggsave(filename = glue("{output_prefix}{feature}_volcano{assay_suffix}.png"), plot = p, device = "png",
       width = 16, height = fig_height, units = "in", dpi = 300,
       path = diff_abund_out_dir, limitsize = FALSE)
)

# Add NCBI id to feature i.e. ASV
tax_names <- map_chr(str_replace_all(taxonomy_table$species, ";_","")  %>%
                       str_split(";"),
                     function(row) row[length(row)])

df <- data.frame(ASV=rownames(taxonomy_table), best_taxonomy=tax_names)

# Pull NCBI IDS for unique taxonomy names
df2 <- data.frame(best_taxonomy = df$best_taxonomy %>%
                    unique()) %>%
  mutate(NCBI_id=get_ncbi_ids(best_taxonomy, target_region),
         .after = best_taxonomy)

df <- df %>%
  left_join(df2, join_by("best_taxonomy")) %>% 
  right_join(merged_stats_df)


# Manually creating a normalized table because normalized 
# tables differ by comparison
normalized_table <- as.data.frame(feature_table + 1) %>%
  rownames_to_column(feature) %>%
  mutate(across( where(is.numeric), log ) )


samples <- metadata[[samples_column]]
samplesdropped <- setdiff(x = samples, y = colnames(normalized_table)[-1])
missing_df <- data.frame(ASV=normalized_table[[feature]],
                         matrix(data = NA, 
                                nrow = nrow(normalized_table),
                                ncol = length(samplesdropped)
                         )
)
colnames(missing_df) <- c(feature,samplesdropped)


group_levels <- metadata[, group] %>% unique() %>% sort()
group_means_df <- normalized_table[feature]
walk(group_levels, function(group_level){
  
  
  mean_col <- glue("Group.Mean_({group_level})")
  std_col <- glue("Group.Stdev_({group_level})")
  
  # Samples that belong to the current group
  Samples <- metadata %>%
    filter(!!sym(group) == group_level) %>%
    pull(!!sym(samples_column))
  # Samples that belong to the current group that are in the normalized table
  Samples <- intersect(colnames(normalized_table), Samples)
  
  temp_df <- normalized_table %>% select(!!feature, all_of(Samples)) %>% 
    rowwise() %>%
    mutate(!!mean_col := mean(c_across(where(is.numeric))),
           !!std_col := sd(c_across(where(is.numeric))) ) %>% 
    select(!!feature,!!sym(mean_col), !!sym(std_col))
  
  group_means_df <<- group_means_df %>% left_join(temp_df)
  
})


# Append Mean and standard deviation
normalized_table <- normalized_table %>%
  rowwise() %>%
  mutate(All.Mean=mean(c_across(where(is.numeric))),
         All.Stdev=sd(c_across(where(is.numeric))) )%>% 
  left_join(missing_df, by = feature) %>% 
  select(!!feature, all_of(samples), All.Mean, All.Stdev)


merged_df <- df  %>%
  left_join(taxonomy_table %>%
              as.data.frame() %>%
              rownames_to_column(feature)) %>% 
  select(!!feature, domain:species,everything()) # Try to generalize


merged_df <- merged_df %>%
  select(!!sym(feature):NCBI_id) %>%
  left_join(normalized_table, by = feature) %>%
  left_join(merged_df) %>% 
  left_join(group_means_df, by = feature) %>% 
  mutate(across(where(is.numeric), ~round(.x, digits=3))) %>% 
  mutate(across(where(is.matrix), as.numeric))

output_file <- glue("{diff_abund_out_dir}/{output_prefix}ancombc1_differential_abundance{assay_suffix}.csv")
message("Writing out results of differential abundance using ANCOMBC1...")
write_csv(merged_df,output_file)


#  --------------- Make log abundance box plots ------------------ #

df2 <- (metadata %>% select(!!samples_column, !!group)) %>% 
  left_join(feature_table %>%
              t %>%
              as.data.frame %>%
              rownames_to_column(samples_column))

message("Making abundance box plots...")
boxplots <- map( merged_stats_df[[feature]], function(feature){
  
  p <- ggplot(df2, aes(x=!!sym(group), y=log(!!sym(feature)+1), fill=!!sym(group) )) +
    geom_boxplot() + 
    labs(x=NULL, y="Log Abundance", fill=tools::toTitleCase(group), title = feature) +
    theme_light() +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
          axis.title.y = element_text(face = "bold", size=12),
          legend.text = element_text(face = "bold", size=10), 
          legend.title = element_text(face = "bold", size=12))
  
  # Save feature boxplot as separate figures
  ggsave(plot = p, filename = glue("{output_prefix}{feature}_boxplot{assay_suffix}.png"), device = "png", 
         width = 8, height = 5, units = "in", dpi = 300, path = diff_abund_out_dir)
  
  return(p)
})


p <- wrap_plots(boxplots, ncol = 2, guides = 'collect')

number_of_features <- merged_stats_df[[feature]] %>% length
number_of_columns <- 2
number_of_rows = ceiling(number_of_features / number_of_columns)
fig_height = 5 * number_of_rows

# Try to Plot all features / ASVs in one figure
try(
ggsave(filename = glue("{output_prefix}{feature}_boxplots{assay_suffix}.png"), plot = p, device = "png",
       width = 14, height = fig_height, units = "in", dpi = 300,
       limitsize = FALSE, path = diff_abund_out_dir)  # There too many things to plot

)

message("Run completed sucessfully.")
