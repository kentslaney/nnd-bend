from ./rng import (key, uniform_, split_2, partition)
from ./util import (select)

def reverse(i):
  if i > 0:
    return List/Cons(i - 1, reverse(i - 1))
  else:
    return List/Nil

def main:
  arr = reverse(64)
  return partition(key(42), arr, 30)

#{
from ./rng import (key, split_2, normal)
from ./rpt import (rp_tree)

def main:
  rng = key(0)
  (rng, subkey) = split_2(rng)
  data = normal(subkey, [64, 8])
  return rp_tree(rng, data, 30, 0.75)
#}
