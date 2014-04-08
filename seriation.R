#!/usr/bin/Rscript
library("seriation")
sim = read.csv("/tmp/ot/sim.csv",FALSE)
sim <- as.dist(sim)
#sort <- seriate(sim)
sort <- seriate(sim,"TSP")
cat(get_order(sort), "\n")
