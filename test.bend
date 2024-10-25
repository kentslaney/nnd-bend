from ./rng import (key, split_2, normal)
from ./rpt import (forest, DirectAccess.create)

def main:
  rng = key(0)
  (subkey0, rng) = split_2(rng)
  (subkey1, rng) = split_2(rng)
  data = DirectAccess.create(normal(subkey0, [256, 1]))
  return forest(subkey1, data, 3, 30, 0.75)
