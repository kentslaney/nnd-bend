from ./rng import (key, uniform_)
from ./util import (median)

def main:
  arr = uniform_(key(42), 31)
  pivot = median(arr)
  lo = List/filter(arr, lambda x: x < pivot)
  return List/length(lo)

#{
from ./rng import (key, split_2, normal)
from ./rpt import (rp_tree)

def main:
  rng = key(0)
  (rng, subkey) = split_2(rng)
  data = normal(subkey, [64, 8])
  return rp_tree(rng, data, 30, 0.75)
#}
