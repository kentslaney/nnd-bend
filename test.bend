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
  data = DirectAccess.create(normal(rng, [8, 3]))
  tree = map_mat_avl(graph(key(42), 8, 4), data, 0)
  tree = DirectAccess.create(tree)
  lo, hi = build(subkey, tree, 4)
  with IO:
    * <- IO/print(Avl.list_repr([lo, hi]))
    return *
