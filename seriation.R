#!/usr/bin/Rscript
library("seriation")
args <- commandArgs(trailingOnly = TRUE)
sim = read.csv(args[1],FALSE)
sim <- as.dist(sim)
sort <- seriate(sim,"OLO") #best
cat(get_order(sort), "\n")

#sort <- seriate(sim)
#sort <- seriate(sim,"ARSA")
#sort <- seriate(sim,"TSP")
#sort <- seriate(sim,"MDS")
#sort <- seriate(sim,"Chen")

#sort <- seriate(sim,"GW")
#pimage(sim,sort)
