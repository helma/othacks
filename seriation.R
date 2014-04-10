#!/usr/bin/Rscript
library("seriation")
args <- commandArgs(trailingOnly = TRUE)
sim = read.csv(args[1],FALSE)
sim <- as.dist(sim)
#sort <- seriate(sim)
sort <- seriate(sim,"TSP")
cat(get_order(sort), "\n")
