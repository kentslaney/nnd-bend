from ./rng import (key, split_2, normal)
from ./rpt import (rp_tree)

def main:
  rng = key(0)
  (rng, subkey) = split_2(rng)
  data = normal(subkey, [64, 8])
  return rp_tree(rng, data, 30, 0.75)
