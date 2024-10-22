from ./rng import (key, split, split_2, randint, bernoulli, zip)

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

def sample(rng, start, end):
  rng = split(rng, 3)
  match rng:
    case List/Cons:
      (rng, nxt) = (rng.head, rng.tail)
      match nxt:
        case List/Cons:
          first = randint(nxt.head, [1], start, end)
          match first:
            case List/Cons:
              first = first.head
            case _:
              first = *
          nxt = nxt.tail
          match nxt:
            case List/Cons:
              second = randint(nxt.head, [1], start, end - 1)
              match second:
                case List/Cons:
                  second = second.head
                case _:
                  second = *
              second += second >= first
              return (rng, first, second)
            case _:
              return *
        case _:
          return *
    case _:
      return *

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

def degenerate(rng, data, index, largest):
  rng, subkey = split_2(rng)
  mask = bernoulli(subkey, [largest], 0.5)
  return *

def rp_split(rng, data, bound, index, largest, prev):
  total = List/length(data)
  (rng, first, second) = sample(rng, 0, total)
  first = list_index(data, first)
  second = list_index(data, second)
  (delta, boundary) = hyperplane(first, second)
  (l, r) = lr_split(delta, boundary, data)
  side = List/length(l)
  if (side == 0) | (side == total) | (side == prev) | (side == total - prev):
    return degenerate(rng, data, index, largest)
  elif (side < (1 - bound) * total) | (side > bound * total):
    return rp_split(rng, data, bound, index, largest, prev)
  else:
    return (rng, l, r)

def main:
  return sample(key(42), 0, 3)
