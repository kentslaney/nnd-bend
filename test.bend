from ann import *
from rng import (key, split_2, normal)

def main:
  rng = key(42)
  rng, subkey = split_2(rng)
  data = normal(rng, [8, 3])
  return ann(subkey, data, 4)
