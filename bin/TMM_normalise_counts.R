#!/usr/bin/env Rscript

if (!require("optparse")){
    install.packages("optparse",repos = "http://cran.us.r-project.org")
}
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager",repos = "http://cran.us.r-project.org")
if (!require("DESeq2")){
    BiocManager::install("DESeq2")
}
if (!require("edgeR")){
    BiocManager::install("edgeR")
}


library(optparse)
library(DESeq2)
library(edgeR)

option_list <- list(
    make_option(c("-c", "--counts"), type="character", default=NULL,
        help="table of read counts per gene", metavar="character"),
    make_option(c("-l", "--lengths"), type="character", default=NULL,
        help="table of effective lengths per gene", metavar="character"),
    make_option(c("-g", "--genes"), type="character", default=NULL,
        help="core gene subset to be used", metavar="character"),
    make_option(c("-p", "--perc"), type="character", default=NULL,
        help="was filtering based on percentage presence of gene?", metavar="character"),
    make_option(c("-t", "--log_transform"), type="character", default=NULL,
        help="log transform the counts? default = FALSE", metavar="character"),
    make_option(c("-o", "--outdir"), type="character", default=NULL,
        help="output directory for results", metavar="character")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

counts_f <- opt$counts
lengths_f <- opt$lengths
gene_f <- opt$genes
perc <- if(opt$perc == "TRUE") TRUE else FALSE
log <- if(opt$log_transform == "TRUE") TRUE else FALSE
outdir <- opt$outdir

## Read data
counts_tab <- read.csv(
    counts_f, header = TRUE, na.strings=c("","NA"), sep = "\t",
    stringsAsFactors = FALSE
)
lengths_tab <- read.csv(
    lengths_f, header = TRUE, na.strings=c("","NA"), sep = "\t",
    stringsAsFactors = FALSE
)
core_genome <- read.csv(
    gene_f, header = TRUE, na.strings=c("","NA"), sep = "\t",
    stringsAsFactors = FALSE
)


if(isFALSE(perc)){
    colnames(core_genome) <- gsub("X", "ST_", colnames(core_genome))
    na_count <- sapply(core_genome, function(y) sum(length(which(is.na(y)))))
    n <- 1
    least_na <- names(sort(na_count)[1:n])
    core_genes <- na.omit(core_genome[least_na])[,1]
} else {
    core_genes <- core_genome$gene
}

colnames(counts_tab)[1] <- colnames(lengths_tab)[1] <- "Gene"

counts_tab <- subset(counts_tab, Gene %in% core_genes)
lengths_tab <- subset(lengths_tab, Gene %in% core_genes)

rownames(counts_tab) <- rownames(lengths_tab) <- counts_tab$Gene
counts_tab$Gene <- lengths_tab$Gene <- NULL

lengths_tab <- lengths_tab[match(rownames(counts_tab), rownames(lengths_tab)),]


## scale counts to reads per median gene length
median_lens <- rowMedians(as.matrix(lengths_tab), na.rm=TRUE)
counts_tab_scaled <- (counts_tab/lengths_tab)
counts_tab_scaled <- sweep(counts_tab_scaled, 1, median_lens, "*")

## Replace missing values with 0
counts_tab_scaled[is.na(counts_tab_scaled)] <- 0


## get CPM
y <- DGEList(counts = counts_tab_scaled)
y <- calcNormFactors(y, method = "TMM")
libSizes <- y$samples$lib.size
res_df <- as.data.frame(cpm(
    y, log = log, lib.size = (libSizes)*(y$samples$norm.factors)
))

## get RPKM
y <- DGEList(
    counts = counts_tab_scaled,
    genes = data.frame(gene.length = median_lens)
)
y <- calcNormFactors(y)
# rpkm_df <- as.data.frame(edgeR::rpkm(y, log = log))
rpkm_df <- as.data.frame(edgeR::rpkm(y, log = FALSE))  ## update: don't log transform the RPKM vals


write.table(
    res_df, file.path(outdir,"norm_counts.tsv"),
    col.names = TRUE, row.names = TRUE,
    sep = "\t", quote = FALSE
)

write.table(
    rpkm_df, file.path(outdir,"rpkm_counts.tsv"),
    col.names = TRUE, row.names = TRUE,
    sep = "\t", quote = FALSE
)
