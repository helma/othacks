#!/usr/bin/Rscript
library("tuneR")
args <- commandArgs(trailingOnly = TRUE)
wav <- readWave(args[1])
plot(wav)
