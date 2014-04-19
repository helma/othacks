#!/usr/bin/Rscript
library("tuneR")
args <- commandArgs(trailingOnly = TRUE)
files <- dir(args[1],args[2],full.names = TRUE)
#par(mfrow = c(ceiling(length(files)/4),4)) # does not work with tuneR
for (i in 1:length(files)) {
  wav <- readWave(files[i])
  plot(wav,axes = FALSE, main = files[i])
}
dev.off()
system("llpp Rplots.pdf")
