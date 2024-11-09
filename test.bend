from ./avl import *
from ./nnd import *
from ./rng import *
from ./map import *
from ./rpt import *
from ./util import *

def map_arr_avl(arr, data, n):
  match arr:
    case List/Nil:
      return Avl/Leaf()
    case List/Cons:
      self = DirectAccess.get(data, n)
      d = diff_tuple(zip(self, DirectAccess.get(data, arr.head)))
      d = sum_list(dot(zip(d, d)))
      key = AvlKey/Dual(d, arr.head, AvlData/Inert(arr.head % 2))
      return Avl.insert(map_arr_avl(arr.tail, data, n), key)

def map_mat_avl(arr, data, n):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      rem = map_mat_avl(arr.tail, data, n + 1)
      return List/Cons(map_arr_avl(arr.head, data, n), rem)

def main:
  rng = key(42)
  rng, subkey = split_2(rng)
  subkey0, subkey1 = split_2(subkey)
  data = DirectAccess.create(normal(rng, [8, 3]))
  tree = map_mat_avl(graph(subkey0, 8, 4), data, 0)
  tree = DirectAccess.create(tree)
  lo, hi = build(subkey1, tree, 4)
  tree, count = reset_flag(tree)
  out = apply(4, data, tree, hi)
  out = bipartite(4, data, out, lo, hi)
  out = bipartite(4, data, out, hi, lo)
  with IO:
    * <- IO/print("updated: ")
    * <- IO/print(Avl.repr_int("\n", count))
    * <- IO/print(Avl.map_repr(out))
    return DirectAccess.to_list(lo), DirectAccess.to_list(hi)
