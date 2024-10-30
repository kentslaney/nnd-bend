from ./npy import *
from ./rng import *

def main:
  data = randint(key(42), [4, 6, 2], 0, 100)
  return save_npy("/mnt/nnd-bend/out.npy", data, [4, 6, 2])
