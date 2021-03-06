#' @title plotMetaGene
#' @param peak the data frame of peak in bed12 format.
#' @param gtf The annotation file.
#' @import Guitar
#' @export
plotMetaGene <- function(peak,gtf){
  feature <- list('peak'=.peakToGRangesList(peak) )
  txdb <- makeTxDbFromGFF(gtf,format = "gtf")
  gc_txdb <- .makeGuitarCoordsFromTxDb(txdb, noBins=50)
  GuitarCoords <- gc_txdb
  m <- .countGuitarDensity(
    feature[[1]],
    GuitarCoords,
    5)
  ct = cbind(m,Feature="peak")
  ct[[4]] <- as.character(ct[[4]])

  ## make plot_no-fill
  ct$weight <- ct$count # as numeric
  ct1 <- ct[ct$category=="mRNA",] # mRNA
  ct2 <- ct[ct$category=="lncRNA",] # lncRNA

  d <- mcols(GuitarCoords)

  pos=Feature=weight=NULL

  id1 <- which(match(ct1$comp,c("Front","Back")) >0 )
  ct1 <- ct1[-id1,]
  id2 <- which(match(ct2$comp,c("Front","Back")) >0 )
  ct2 <- ct2[-id2,]

  # normalize feature
  featureSet <- as.character(unique(ct$Feature))
  for (i in 1:length(featureSet)) {
    id <- (ct1$Feature==featureSet[i])
    ct1$weight[id] <- ct1$weight[id]/sum(ct1$weight[id])

    id <- (ct2$Feature==featureSet[i])
    ct2$weight[id] <- ct2$weight[id]/sum(ct2$weight[id])
  }

  p2 <-
    ggplot(ct2, aes(x=pos, weight=weight)) +
    ggtitle("Distribution on lncRNA")  +
    xlab("") +
    ylab("Frequency") +
    geom_density(adjust=1,aes(fill=factor(Feature),colour=factor(Feature)),alpha=0.2) +
    annotate("text", x = 0.5, y = -0.2, label = "lncRNA")+
    annotate("rect", xmin = 0, xmax = 1, ymin = -0.12, ymax = -0.08, alpha = .99, colour = "black")+
    theme_bw() + theme(axis.ticks = element_blank(), axis.text.x = element_blank(),panel.border = element_blank(), panel.grid.major = element_blank(),
                       panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"), plot.title = element_text(face = "bold",hjust = 0.5))

  # normalization by length of components in mRNA
  # calculate relative length of each components
  temp <- unique(d[,c(1,3,4,5)])
  id1 <- which(match(temp$comp,c("Front","Back")) >0 )
  temp <- temp[-id1,] # remove DNA
  id1 <- which(match(temp$category,"mRNA") >0 )
  temp <- temp[id1,]
  temp <- matrix(temp$interval,ncol=3)
  temp <- temp/rowSums(temp)
  temp <- colSums(temp)
  temp <-temp/sum(temp)
  weight <- temp
  names(weight) <- c("5'UTR","CDS","3'UTR")

  # density
  cds_id <- which(ct1$comp=="CDS")
  utr3_id <- which(ct1$comp=="UTR3")
  utr5_id <- which(ct1$comp=="UTR5")
  ct1$count[utr5_id] <- ct1$count[utr5_id]*weight["5'UTR"]
  ct1$count[cds_id] <- ct1$count[cds_id]*weight["CDS"]
  ct1$count[utr3_id] <- ct1$count[utr3_id]*weight["3'UTR"]

  # re-normalization
  featureSet <- as.character(unique(ct$Feature))
  for (i in 1:length(featureSet)) {
    id <- (ct1$Feature==featureSet[i])
    ct1$weight[id] <- ct1$count[id]/sum(ct1$count[id])
  }
  x <- cumsum(weight)
  ct1$pos[utr5_id] <- ct1$pos[utr5_id]*weight["5'UTR"] + 0
  ct1$pos[cds_id] <- ct1$pos[cds_id]*weight["CDS"] + x[1]
  ct1$pos[utr3_id] <- ct1$pos[utr3_id]*weight["3'UTR"] + x[2]

  p1 <-
    ggplot(ct1, aes(x=pos, weight=weight))  +
    ggtitle("Distribution on mRNA") +
    xlab("") +
    ylab("Frequency") +
    geom_density(adjust=1,aes(fill=factor(Feature),colour=factor(Feature)),alpha=0.2) +
    annotate("text", x = x[1]/2, y = -0.2, label = "5'UTR") +
    annotate("text", x = x[1] + weight[2]/2, y = -0.2, label = "CDS") +
    annotate("text", x = x[2] + weight[3]/2, y = -0.2, label = "3'UTR") +
    geom_vline(xintercept= x[1:2], linetype="dotted") +
    annotate("rect", xmin = 0, xmax = x[1], ymin = -0.12, ymax = -0.08, alpha = .99, colour = "black")+
    annotate("rect", xmin = x[2], xmax = 1, ymin = -0.12, ymax = -0.08, alpha = .99, colour = "black")+
    annotate("rect", xmin = x[1], xmax = x[2], ymin = -0.16, ymax = -0.04, alpha = .2, colour = "black")+
    theme_bw() + theme(axis.ticks = element_blank(), axis.text.x = element_blank(),panel.border = element_blank(), panel.grid.major = element_blank(),
                       panel.grid.minor = element_blank(), axis.line = element_line(colour = "black"),legend.position = "none",legend.text = element_text(face = "bold"), legend.title = element_blank(), plot.title = element_text(face = "bold",hjust = 0.5))

  .multiplot(p1, p2, cols=2)
  
  cat("NOTE this function is a wrapper for R package \"Guitar\".\nIf you use the metaGene plot in publication, please cite the original reference:\nCui et al 2016 BioMed Research International \n")
}


#' @title plotMEtaGeneMulti A wrapper function for Guitar to plot meta gene plot of multiple samples overlaid on each other.
#' @param peakList The list of peak, each object of list should have a data frame of peak in bed12 format.
#' @param gtf The annotation file for the gene model.
#' @param saveToPDFprefix Set a name to save the plot to PDF.
#' @param includeNeighborDNA Whether to include upstrean and downstream region in the meta gene.
#' @import Guitar
#' @export
plotMetaGeneMulti <- function(peakList,gtf,saveToPDFprefix=NA,
                              includeNeighborDNA=FALSE){

  gfeature <- lapply(peakList,.peakToGRangesList)
  names(gfeature) <- names(peakList)
  txdb <- makeTxDbFromGFF(gtf,format = "gtf")
  gc_txdb <- .makeGuitarCoordsFromTxDb(txdb, noBins=50)

  GuitarPlotNew(gfeature, GuitarCoordsFromTxDb = gc_txdb,saveToPDFprefix=saveToPDFprefix,
             includeNeighborDNA=includeNeighborDNA)
  
  cat("NOTE this function is a wrapper for R package \"Guitar\".\nIf you use the metaGene plot in publication, please cite the original reference:\nCui et al 2016 BioMed Research International \n")
  
}
