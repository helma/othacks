@basedir = "/media/ot/ISS"

@chains = [
  "KICK",
  "SNR",
  "HH",
  #"PERC",
  "SUB",
  "BASS",
  "LEAD",
  "STAB",
  "PAD",
  #"AMBIENT",
  #"VOICE"
]

@external_chains = Dir.wavs(File.join @basedir, "AUDIO/Tarekith Octatrack Chains/Instrument Chains").sort

@projects = [
  "086",
  "098",
  "114",
  "120",
  "124",
  "128",
  "132",
  "140",
  "156",
  "174",
]

@instruments = [
  "drums",
  "sub",
  "music"
]

@external_matrices = {
  "120" => ["/media/ot/ISS/AUDIO/matrix/MX chains"],
  "174" => [
    "/media/ot/ISS/AUDIO/musicradar/musicradar-dnb-breaks-samples/matrix/1",
    "/media/ot/ISS/AUDIO/musicradar/musicradar-dnb-breaks-samples/matrix/2",
  ]
}
