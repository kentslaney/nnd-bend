from ann import (ann,)
from rng import (key, split_2, normal)
from npy import (load_npy, save_npy)

def main:
  k, rng = 4, key(42)
  with IO:
    data <- load_npy("/mnt/nnd-bend/in.npy")
    points, data = List/length(data)
    * <- save_npy("/mnt/nnd-bend/out.npy", ann(rng, data, k), [points, k])
    return *
