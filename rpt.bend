from ./rng import (key, split, split_2, randint, bernoulli, zip)

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
        return list_index(arr, index - 1)
    case List/Nil:
      return *

def diff_tuple(it):
  (l, r) = it
  return l - r

def sum_list(it):
  match it:
    case List/Cons:
      return it.head + sum_list(it.tail)
    case List/Nil:
      return 0

def mean_dot(args):
  (delta, (left, right)) = args
  return delta * (left + right) / 2

def hyperplane(left, right):
  delta = [diff_tuple(i) for i in zip(left, right)]
  boundary = sum_list([mean_dot(i) for i in zip(delta, zip(left, right))])
  return (delta, boundary)

def dot(args):
  (l, r) = args
  return l * r

def lr_split(delta, boundary, data):
  match data:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      (l, r) = lr_split(delta, boundary, data.tail)
      if sum_list([dot(i) for i in zip(delta, data.head)]) > boundary:
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

def sided(it):
  match it:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      l, r = sided(it.tail)
      mask, data = it.head
      if mask:
        return (l, List/Cons(data, r))
      else:
        return (List/Cons(data, l), r)

def max(x, y):
  if x > y:
    return x
  else:
    return y

def degenerate(rng, data, size, args, j):
  (largest, total, *, bound) = args
  rng, subkey = split_2(rng)
  mask = bernoulli(subkey, [largest], 0.5)
  mask = postfix(mask, max(j + largest - total, 0))
  (l, r) = sided(zip(mask, data))
  side = List/length(l)
  if (side < (1 - bound) * size) | (side > bound * size):
    return degenerate(rng, data, bound, j)
  else:
    (l, r) = (DirectAccess/Leaf(l), DirectAccess/Leaf(r))
    return (rng, DirectAccess/Node(j + side, l, r))

def rp_split(rng, data, args, j, prev):
  (*, *, goal_leaf_size, bound) = args
  size = List/length(data)
  if size <= goal_leaf_size:
    return !data
  else:
    (rng, first, second) = sample(rng, 0, size)
    first = list_index(data, first)
    second = list_index(data, second)
    (delta, boundary) = hyperplane(first, second)
    (l, r) = lr_split(delta, boundary, data)
    side = List/length(l)
    if (side == 0) | (side == size) | (side == prev) | (side == size - prev):
      return degenerate(rng, data, size, args, j)
    elif (side < (1 - bound) * size) | (side > bound * size):
      return rp_split(rng, data, args, j, side)
    else:
      (l, r) = (DirectAccess/Leaf(l), DirectAccess/Leaf(r))
      return (rng, DirectAccess/Node(j + side, l, r))

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
      return rp_split(rng, data, args, j, 0)

def rp_tree_outer(rng, data, args, loops, i):
  if i >= loops:
    return (rng, data)
  else:
    (total, *, bound) = args
    largest = Math/ceil(total * bound ** i)
    layer_size = 2 ** i
    args = (largest, args)
    subkeys = split(rng, layer_size + 1)
    (rng, subkeys) = split_out(rng)
    subkeys = DirectAccess.create(subkeys)
    (rng, data) = rp_tree_inner(subkeys, data, args, total, 0)
    return rp_tree_outer(rng, data, args, loops, i + 1)

def rp_tree(rng, data, goal_leaf_size: u24, bound: f24):
  (total, data) = List/length(data)
  min = max_order(total / goal_leaf_size + ((total % goal_leaf_size) != 0) - 1)
  args = (total, goal_leaf_size, bound)
  return rp_tree_outer(rng, DirectAccess/Leaf(data), args, min, 0)

def main:
  return sample(key(42), 0, 3)
