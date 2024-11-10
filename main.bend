from ann import (ann,)
from rng import (key,)
from npy import (load_npy, save_npy)

def main(k):
  rng = key(0)
  with IO:
    data <- load_npy("in.npy")
    points, data = List/length(data)
    * <- save_npy("out.npy", ann(rng, data, k), [points, k])
    return *
