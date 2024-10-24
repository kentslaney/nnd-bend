from ./rng import (split, split_2, randint, bernoulli, partition)
from ./util import (zip, sided, max)

def max_order_(bin, pos):
  if (bin >> pos) | (pos == 0):
    return pos
  else:
    return max_order_(bin, pos - 1)

def max_order(bin):
  return max_order_(bin, 23)

def flip_(bin, pad, res, pos):
  res = res << 1 | ((bin >> pos) & 1)
  if pos < pad:
    return flip_(bin, pad, res, pos + 1)
  else:
    return res

def flip(bin: u24):
  return flip_(bin, max_order(bin), 0, 0)

def test_flip():
  return flip(0b11001) == 0b10011

type DirectAccess: # < index goes left
  Node { index, ~left, ~right }
  Leaf { value }

def DirectAccess.create_(arr, len, el):
  if len == 1:
    match arr:
      case List/Nil:
        return (DirectAccess/Leaf(List/Nil), List/Nil)
      case List/Cons:
        return (DirectAccess/Leaf(arr.head), arr.tail)
  else:
    (tree0, arr) = DirectAccess.create_(arr, len / 2, el)
    (tree1, arr) = DirectAccess.create_(arr, len / 2 + (len % 2), el + len / 2)
    return (DirectAccess/Node(el + len / 2, tree0, tree1), arr)

def DirectAccess.create(arr):
  (len, arr) = List/length(arr)
  (res, *) = DirectAccess.create_(arr, len, 0)
  return res

def DirectAccess.get(self, el):
  match self:
    case DirectAccess/Node:
      if el < self.index:
        return DirectAccess.get(self.left, el)
      else:
        return DirectAccess.get(self.right, el)
    case DirectAccess/Leaf:
      return self.value

def split_out(subkeys):
  match subkeys:
    case List/Nil:
      return (*, List/Nil)
    case List/Cons:
      return (subkeys.head, subkeys.tail)

def unwrap_singleton(arr):
  match arr:
    case List/Nil:
      return *
    case List/Cons:
      return arr.head

def sample(rng, start, end):
  rng = split(rng, 3)
  rng, nxt = split_out(rng)
  first, nxt = split_out(rng)
  second, * = split_out(rng)

  first = unwrap_singleton(randint(first, [1], start, end))
  second = unwrap_singleton(randint(second, [1], start, end - 1))
  second += second >= first
  return (rng, first, second)

def list_index(arr, index):
  match arr:
    case List/Cons:
      if index == 0:
        return arr.head
      else:
        return list_index(arr.tail, index - 1)
    case List/Nil:
      return *

def diff_tuple(it):
  match it:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (l, r) = it.head
      return List/Cons(l - r, diff_tuple(it.tail))

def sum_list(it):
  match it:
    case List/Cons:
      return it.head + sum_list(it.tail)
    case List/Nil:
      return 0.0

def mean_dot(it):
  match it:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (delta, (left, right)) = it.head
      return List/Cons(delta * (left + right) / 2.0, mean_dot(it.tail))

def hyperplane(left, right):
  delta = diff_tuple(zip(left, right))
  boundary = sum_list(mean_dot(zip(delta, zip(left, right))))
  return (delta, boundary)

def dot(it):
  match it:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (l, r) = it.head
      return List/Cons(l * r, dot(it.tail))

def lr_split(delta, boundary, data):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      (l, r) = lr_split(delta, boundary, data.tail)
      if sum_list(dot(zip(delta, data.head))) > boundary:
        return (l, List/Cons(data.head, r))
      else:
        return (List/Cons(data.head, l), r)

def postfix(arr, size):
  if size == 0:
    return arr
  else:
    match arr:
      case List/Cons:
        return postfix(arr.tail, size - 1)
      case _:
        return List/Nil

# TODO: these should operate by index instead of value
def degenerate(rng, data, size, args, j):
  (largest, total, *, bound) = args
  rng, subkey = split_2(rng)
  mask = bernoulli(subkey, [largest], 0.5)
  mask = postfix(mask, max(j + largest - total, 0))
  (l, r) = sided(zip(mask, data))
  (side, l) = List/length(l)
  if (side < (1.0 - bound) * size) | (side > bound * size):
    return degenerate(rng, data, bound, j)
  else:
    (l, r) = (DirectAccess/Leaf(l), DirectAccess/Leaf(r))
    return DirectAccess/Node(j + side, l, r)

def rp_split(rng, data, args, j, prev):
  (*, *, goal_leaf_size, bound) = args
  (size, data) = List/length(data)
  if size <= goal_leaf_size:
    return DirectAccess/Leaf(data)
  else:
    (rng, first, second) = sample(rng, 0, size)
    first = list_index(data, first)
    second = list_index(data, second)
    (delta, boundary) = hyperplane(first, second)
    (l, r) = lr_split(delta, boundary, data)
    (side, l) = List/length(l)
    (fp_side, fp_size) = (u24/to_f24(side), u24/to_f24(size))
    if (side == 0) | (side == size) | (side == prev) | (side == size - prev):
      return degenerate(rng, data, size, args, j)
    elif (fp_side < (1.0 - bound) * fp_size) | (fp_side > bound * fp_size):
      return rp_split(rng, data, args, j, side)
    else:
      (l, r) = (DirectAccess/Leaf(l), DirectAccess/Leaf(r))
      return DirectAccess/Node(j + side, l, r)

def rp_tree_inner(rng, data, args, j):
  match data:
    case DirectAccess/Node:
      match rng:
        case DirectAccess/Node:
          (l, r) = (rng.left, rng.right)
        case _:
          (l, r) = (*, *)
      first = rp_tree_inner(l, data.left, args, j)
      second = rp_tree_inner(r, data.right, args, data.index)
      return DirectAccess/Node(data.index, first, second)
    case DirectAccess/Leaf:
      data = data.value
      match rng:
        case DirectAccess/Node:
          rng = *
        case _:
          rng = rng.value
      return rp_split(rng, data, args, j, 0)

def rp_tree_outer(rng, data, args, loops, i):
  if i >= loops:
    return data
  else:
    (total, *, bound) = args
    largest = f24/to_u24(Math/ceil(u24/to_f24(total) * bound ** u24/to_f24(i)))
    layer_size = 1 << i
    inner_args = (largest, args)
    subkeys = split(rng, layer_size + 1)
    (rng, subkeys) = split_out(subkeys)
    subkeys = DirectAccess.create(subkeys)
    data = rp_tree_inner(subkeys, data, inner_args, 0)
    return rp_tree_outer(rng, data, args, loops, i + 1)

def rp_tree(rng, data, goal_leaf_size: u24, bound: f24):
  (total, data) = List/length(data)
  rem = (total % goal_leaf_size) != 0
  min = max_order(total / goal_leaf_size + rem - 1) + 1
  args = (total, goal_leaf_size, bound)
  return rp_tree_outer(rng, DirectAccess/Leaf(data), args, min, 0)

def flatten_(rng, data, limit):
  match data:
    case DirectAccess/Leaf:
      (len, arr) = List/length(data.value)
      if len > limit:
        return partition(rng, arr, limit)
      else:
        return [arr]
    case DirectAccess/Node:
      (l, r) = split_2(rng)
      (l, r) = (flatten_(l, data.left, limit), flatten_(r, data.right, limit))
      return List/concat(l, r)

def flatten_loop(it, limit):
  match it:
    case List/Cons:
      (rng, data) = it.head
      return List/Cons(flatten_(rng, data, limit), flatten_loop(it.tail, limit))
    case List/Nil:
      return List/Nil

def flatten(rng, data, limit):
  (len, data) = List/length(data)
  subkeys = split(rng, len)
  return List/flatten(flatten_loop(zip(subkeys, data), limit))

def forest_(subkeys, data, limit, bound):
  match subkeys:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (rng, sub0) = split_2(subkeys.head)
      (rng, sub1) = split_2(rng)
      # TODO: get this working with one split
      res = rp_tree(sub0, data, limit, bound)
      res = flatten_(sub1, res, limit)
      return List/Cons(res, forest_(subkeys.tail, data, limit, bound))

def forest(rng, data, trees, goal_leaf_size: u24, bound: f24):
  subkeys = split(rng, trees)
  return List/flatten(forest_(subkeys, data, goal_leaf_size, bound))

def main:
  return *
