#' tqDist wrapper
#' 
#' Convenience function that takes a list of trees, writes them to a text file,
#' and calls tqDist on the generated file (which is deleted on completion).
#' 
#' Quartets can be resolved in one of five ways, which 
#'  Brodal _et al_. (2013) and Holt _et al_. (2014) distinguish using the letters
#'  A--E, and Estabrook (1985) refers to as:
#'  
#'  A: $s$ = resolved the ***s***ame in both tres
#'  B: $d$ = resolved ***d***ifferently in both trees
#'  C: $r_1$ = ***r***esolved only in tree ***1***
#'  D: $r_2$ = ***r***esolved only in tree ***2***
#'  E: $u$ = ***u***nresolved in both trees
#'  
#' 
#' @param treeList List of phylogenetic trees, of class \code{list} or
#'                 \code{phylo}. All trees must be bifurcating.
#' @return `TQDist` returns the quartet distance between each pair of trees
#' @references
#'   \insertRef{Brodal2013}{Quartet}
#'   \insertRef{Estabrook1985}{Quartet}
#'   \insertRef{Holt2014}{Quartet}
#'   \insertRef{Sand2014}{Quartet}
#' @importFrom ape write.tree
#' @importFrom stats runif
#' @author Martin R. Smith
#' @export
TQDist <- function (treeList) {
  fileName <- TQFile(treeList)
  on.exit(file.remove(fileName))
  AllPairsQuartetDistance(fileName)
}

#' @describeIn TQDist Number of agreeing quartets that are resolved / unresolved
#' @author Martin R. Smith
#' @return `TQDist` returns the number of resolved quartets in agreement between 
#'   each pair of trees (A in Brodal _et al_. 2013) and the number of quartets 
#'   that are unresolved in both trees (E in Brodal _et al_. 2013).
#' @export 
TQAE <- function (treeList) {
  fileName <- TQFile(treeList)
  on.exit(file.remove(fileName))
  AllPairsQuartetAgreement(fileName)
}

#' @describeIn TQDist Agreement of each quartet
#' @author Martin R. Smith
#' @return `QuartetAgreement` returns a three-dimensional array listing,
#'   for each pair of trees in turn, the number of quartets in each category.
#' @export 
QuartetAgreement <- function(treeList) {
  AE <- TQAE(treeList)
  nTree <- dim(AE)[1]
  A   <- ae[, , 1]
  E   <- ae[, , 2]
  ABD <- matrix(diag(A), nTree, nTree)
  CE  <- matrix(diag(E), nTree, nTree)
  DE  <- t(DE)
  C   <- CE - AE[, , 2]
  D   <- DE - AE[, , 2]
  B   <- ABD - A - D
  
  # Return:
  array(c(A, B, C, D, E), dim=c(nTree, nTree, 5),
        dimnames = list(NULL, NULL, c('s', 'd', 'r1', 'r2', 'u')))
}


#' Matching Quartets
#' 
#' Counts matching quartets
#' 
#' Determines the number of quartets consistent with multiple cladograms
#' 
#' Given a list of trees, returns the number of quartet statements present in
#'  the first tree in the list also present in each other tree.
#' 
#' At present the trees must bear the same number of tips.  
#' Support for different-sized trees will be added if there is demand; 
#'   contact the maintainer if you would appreciate this functionality.
#'       
#' A random pair of fully-resolved trees is expected to share 
#'    \code{choose(n_tip, 4) / 3} quartets.
#' 
#' @template treesParam
#' @template treesCfParam
#' 
#' @templateVar intro Returns a two dimensional array. Columns correspond to the input trees; the first column will always         report a perfect match as it compares the first tree to itself.         Rows list the status of each quartet:
#' @template returnEstabrook
#'         
#' @author Martin R. Smith
#' @examples{
#'  n_tip <- 6
#'  data(sq_trees)
#'  qt <- MatchingQuartets(sq_trees)
#'
#'  # Calculate Estabrook et al's similarity measures:
#'  do_not_conflict = qt[]
#' }
#' 
#' @seealso [MatchingSplits]
#' 
#' @references {
#'   \insertRef{Estabrook1985}{Quartet}
#'   \insertRef{Sand2014}{Quartet}
#' }
#'
#' @importFrom Rdpack reprompt 
#' @importFrom TreeSearch RenumberTips
#' @export
MatchingQuartets <- function (trees, cf=NULL) {
  if (!is.null(cf)) trees <- UnshiftTree(cf, trees)
  
  treeStats <- vapply(trees, function (tr)
    c(tr$Nnode, length(tr$tip.label)), double(2))
  if (length(unique(treeStats[2, ])) > 1) {
    stop("All trees must have the same number of tips")
  }
  
  QuartetAgreement(trees) ## We only need pairs!
  if (length(unique(treeStats[1, ])) == 1 && treeStats[2, 1] - treeStats[1, 1] == 1) {
    tqDistances <- TQDist(trees)
    nTrees <- length(trees)
    nQuartets <- choose(length(trees[[1]]$tip.label), 4)
    tqDiffs <- tqDistances[1, ]
    t(data.frame(
      Q = rep(nQuartets, nTrees),
      s = nQuartets - tqDiffs,
      d = tqDiffs,
      r1 = integer(nTrees),
      r2 = integer(nTrees),
      u = integer(nTrees)
    ))
  }
  
  tree1Labels <- trees[[1]]$tip.label
  trees <- lapply(trees, RenumberTips, tipOrder = tree1Labels)
  quartets <- QuartetStates(lapply(trees, Tree2Splits))
  ret <- vapply(quartets, CompareQuartets, cf=quartets[[1]], double(6))
  
  # Return:
  if (is.null(cf)) ret else ret[, -1]
}+
#' tqDist file generator
#' 
#' Creates a temporary file corresponding to a list of trees,
#' to be processed with tqDist.  Files should be destroyed using
#' `on.exit(file.remove(fileName))` by the calling function.
#' @return Name of the created file
#' @keywords internal
#' @export
TQFile <- function (treeList) {
  if (class(treeList) == 'list') class(treeList) <- 'multiPhylo'
  if (class(treeList) != 'multiPhylo') stop("treeList must be a list of phylogenetic trees")
  fileName <- paste0('~temp', substring(runif(1), 3), '.trees')
  write.tree(treeList, file=fileName)
  # Return:
  fileName
}

#' Triplet and quartet distances with tqDist
#' 
#' Functions to calculate triplet and quartet distances between pairs of trees.
#' 
#' @param file,file1,file2 Paths to files containing a tree or trees in Newick format.
#' 
#' @return `Distance` functions return the distance between the requested trees.
#' `Agreement` functions return the number of triplets or quartets that are:
#'  `A`, resolved in the same fashion in both trees;
#'  `E`, unresolved in both trees.
#'  Comparing a tree against itself yields the totals (A+B+C) and (D+E) 
#'  referred to by Brodal _et al_. (2013) and Holt _et al_. (2014).
#' 
#' @author Martin R. Smith, after Andreas Sand
#' 
#' @references \insertRef{Sand2014}{Quartet}
#'   \insertRef{Brodal2013}{Quartet}
#'   \insertRef{Holt2014}{Quartet}
#' @export
QuartetDistance <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  .Call('_Quartet_tqdist_QuartetDistance', as.character(file1), as.character(file2));
}

#' @describeIn QuartetDistance Returns a vector of length two, listing \[1\]
#' the number of resolved quartets that agree ('A');
#' \[2\] the number of quartets that are unresolved in both trees ('E').
#' See Brodal et al. (2013).
#'  
#' @export
QuartetAgreement <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  .Call('_Quartet_tqdist_QuartetAgreement', as.character(file1), as.character(file2));
}

#' @export
#' @importFrom ape read.tree
#' @describeIn QuartetDistance Quartet distance between the tree on each line of `file1`
#'   and the tree on the corresponding line of `file2`
PairsQuartetDistance <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  trees1 <- read.tree(file1)
  trees2 <- read.tree(file2)
  if (length(trees1) != length(trees2) || class(trees1) != class(trees2)) {
    stop("file1 and file2 must contain the same number of trees")
  }
  .Call('_Quartet_tqdist_PairsQuartetDistance', as.character(file1), as.character(file2));
}

#' @export
#' @importFrom ape read.tree
#' @describeIn QuartetDistance Quartet distance between the tree in 
#'  `file1` and the tree on each line of `file2`
OneToManyQuartetAgreement <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  trees1 <- read.tree(file1)
  trees2 <- read.tree(file2)
  if (class(trees1) != "phylo") {
    stop("file1 must contain a single tree")
  }
  if (length(trees2) < 1) {
    stop("file2 must contain at least one tree")
  }
  matrix(.Call('_Quartet_tqdist_OneToManyQuartetAgreement', 
               as.character(file1), as.character(file2)),
         nrow=2, dimnames=list(c('A', 'E'), NULL))
}

#' @export
#' @describeIn QuartetDistance Quartet distance between each tree listed in `file` and 
#'   each other tree therein
AllPairsQuartetDistance <- function(file) {
  ValidateQuartetFile(file)
  .Call('_Quartet_tqdist_AllPairsQuartetDistance', as.character(file));
}

#' @export
#' @describeIn QuartetDistance Quartet status for each pair of trees in `file`
AllPairsQuartetAgreement <- function(file) {
  ValidateQuartetFile(file)
  result <- .Call('_Quartet_tqdist_AllPairsQuartetAgreement', as.character(file));
  nTrees <- nrow(result)
  array(result, c(nTrees, nTrees, 2), dimnames=list(NULL, NULL, c('A', 'E')))
}

#' @export
#' @describeIn QuartetDistance Triplet distance between the single tree given 
#'   in each file
TripletDistance <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  .Call('_Quartet_tqdist_TripletDistance', as.character(file1), as.character(file2));
}

#' @export
#' @describeIn QuartetDistance Triplet distance between the tree on each line of `file1`
#'   and the tree on the corresponding line of `file2`
PairsTripletDistance <- function(file1, file2) {
  ValidateQuartetFile(file1)
  ValidateQuartetFile(file2)
  .Call('_Quartet_tqdist_PairsTripletDistance', as.character(file1), as.character(file2));
}

#' @export
#' @describeIn QuartetDistance Triplet distance between each tree listed in `file` and 
#'   each other tree therein
AllPairsTripletDistance <- function(file) {
  ValidateQuartetFile(file)
  .Call('_Quartet_tqdist_AllPairsTripletDistance', as.character(file));
}

#' Validate filenames
#' 
#' Verifies that file parameters are character strings describing files that exist
#' 
#' @param file Variable to validate
#' 
#' @return `TRUE` if `file` is a character vector of length one describing 
#'   a file that exists, a fatal error otherwise.
#' 
#' @author Martin R. Smith
#' 
#' @export
#' @keywords internal
ValidateQuartetFile <- function (file) {
  if (length(file) != 1) {
    stop("file must be a character vector of length one")
  }
  if (!file.exists(file)) {
    stop("file ", file, " not found")
  }
}