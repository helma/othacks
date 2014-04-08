# remove size equally spaced elements from array
# http://stackoverflow.com/questions/5250285/how-to-remove-equally-spaced-elements-from-an-array-with-length-of-n-to-match
# Alternative:
# http://stackoverflow.com/questions/5250285/how-to-remove-equally-spaced-elements-from-an-array-with-length-of-n-to-match
class Array
  def pare size
    new = Array.new size
    n2 = self.length - 2
    m2 = size - 2
    new[0] = self[0]
    i = 0
    j = 0
    while (j < n2) do
      diff = (i+1)*n2 - (j+1)*m2
      if (diff < n2/2)
        i += 1
        j += 1
        new[i] = self[j]
      else
        j += 1
      end
    end
    new[m2+1] = self[n2+1]
    new
  end
end

def select_samples dir
  puts File.join(dir,"*.wav")
  samples = Dir[File.join(dir,"*.wav")]
  puts samples.inspect
  samples.delete_if {|s| File.basename(s).match(File.basename(dir))}
  puts samples.inspect
  nr = samples.size
  if nr >= 128
    exit "more than 129 samples"
  elsif nr >= 64
    samples.pare 64
  elsif nr >= 48
    samples.pare 48
  elsif nr >= 32
    samples.pare 32
  elsif nr >= 16
    samples.pare 16
  elsif nr >= 8
    samples.pare 8
  else
    samples.pare 4
  end
end

