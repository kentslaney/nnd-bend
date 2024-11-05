from ./rng import (split, split_2, randint, bernoulli, partition)
from ./util import (
  zip, sided, max, max_order, list_index, range, postfix, split_out,
  unwrap_singleton
)
from ./map import *

def sample(rng, start, end):
  rng = split(rng, 3)
  rng, nxt = split_out(rng)
  first, nxt = split_out(rng)
  second, * = split_out(rng)

  first = unwrap_singleton(randint(first, [1], start, end))
  second = unwrap_singleton(randint(second, [1], start, end - 1))
  second += second >= first
  return (rng, first, second)

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

def hyperplane(left, right, ref):
  (left, right) = (DirectAccess.get(ref, left), DirectAccess.get(ref, right))
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

def lr_split(delta, boundary, data, ref):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      (l, r) = lr_split(delta, boundary, data.tail, ref)
      el = DirectAccess.get(ref, data.head)
      if sum_list(dot(zip(delta, el))) > boundary:
        return (l, List/Cons(data.head, r))
      else:
        return (List/Cons(data.head, l), r)

def degenerate(rng, data, size, args, j):
  (largest, total, *, bound, *) = args
  rng, subkey = split_2(rng)
  # fixed size mask to make allocation easier and match JAX
  mask = bernoulli(subkey, [largest], 0.5)
  mask = postfix(mask, max(j + largest - total, 0))
  (l, r) = sided(zip(mask, data))
  (side, l) = List/length(l)
  if (side < (1.0 - bound) * size) | (side > bound * size):
    return degenerate(rng, data, size, args, j)
  else:
    (l, r) = (DirectAccess/Leaf(l), DirectAccess/Leaf(r))
    return DirectAccess/Node(j + side, l, r)

def rp_split(rng, data, args, j, prev):
  (*, *, goal_leaf_size, bound, ref) = args
  (size, data) = List/length(data)
  if size <= goal_leaf_size:
    return DirectAccess/Leaf(data)
  else:
    (rng, first, second) = sample(rng, 0, size)
    first = list_index(data, first)
    second = list_index(data, second)
    (delta, boundary) = hyperplane(first, second, ref)
    (l, r) = lr_split(delta, boundary, data, ref)
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
    (total, *, bound, *) = args
    largest = f24/to_u24(Math/ceil(u24/to_f24(total) * bound ** u24/to_f24(i)))
    layer_size = 1 << i
    inner_args = (largest, args)
    subkeys = split(rng, layer_size + 1)
    (rng, subkeys) = split_out(subkeys)
    subkeys = DirectAccess.create(subkeys)
    data = rp_tree_inner(subkeys, data, inner_args, 0)
    return rp_tree_outer(rng, data, args, loops, i + 1)

def rp_tree(rng, data, goal_leaf_size: u24, bound: f24):
  (total, data) = DirectAccess.length(data)
  rem = (total % goal_leaf_size) > 0
  min = max_order(total / goal_leaf_size + rem - 1) + 1
  args = (total, goal_leaf_size, bound, data)
  return rp_tree_outer(rng, DirectAccess/Leaf(range(total)), args, min, 0)

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
      (rng, subkey) = split_2(subkeys.head)
      res = rp_tree(subkey, data, limit, bound)
      res = flatten_(rng, res, limit)
      return List/Cons(res, forest_(subkeys.tail, data, limit, bound))

def forest(rng, data, trees, goal_leaf_size: u24, bound: f24):
  subkeys = split(rng, trees)
  return List/flatten(forest_(subkeys, data, goal_leaf_size, bound))
