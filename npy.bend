from ./util import (list_index)

npy_prefix = "NUMPY"

def match_prefix(str, prefix):
  match prefix:
    case List/Nil:
      return str
    case List/Cons:
      match str:
        case List/Nil:
          return List/Nil
        case List/Cons:
          return match_prefix(str.tail, prefix.tail)

def take(arr, n):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      if n == 0:
        return List/Nil
      else:
        return List/Cons(arr.head, take(arr.tail, n - 1))

def bytes_to_u24(bytes, init):
  match bytes:
    case List/Cons:
      return bytes_to_u24(bytes.tail, (init << 8) | bytes.head)
    case List/Nil:
      return init

def header_bounds(path):
  with IO:
    res_fd <- IO/FS/open(path, "r")
    match res_fd:
      case Result/Err:
        return wrap(*)
      case Result/Ok:
        fd = res_fd.val
        preamble <- IO/FS/read(fd, 12)
        match preamble:
          case Result/Err:
            return wrap(*)
          case Result/Ok:
            closing <- IO/FS/close(fd)
            match closing:
              case Result/Err:
                return wrap(*)
              case Result/Ok:
                match preamble.val:
                  case List/Nil:
                    return wrap(*)
                  case List/Cons:
                    if (preamble.val.head & 0xff) != 0x93:
                      return wrap(*)
                    else:
                      version = match_prefix(preamble.val.tail, npy_prefix)
                      match version:
                        case List/Nil:
                          return wrap(*)
                        case List/Cons:
                          major = version.head
                          if major < 1 | major > 3:
                            return wrap(*)
                          else:
                            minor = version.tail
                            match minor:
                              case List/Nil:
                                return wrap(*)
                              case List/Cons:
                                if minor.head > 0:
                                  return wrap(*)
                                else:
                                  if major == 1:
                                    size = 2
                                  else:
                                    size = 4
                                  substr = take(version, size)
                                  end = bytes_to_u24(substr, 0) / 2
                                  return wrap((8 + size, end))

def read_header(path, start, end):
  with IO:
    res_fd <- IO/FS/open(path, "r")
    match res_fd:
      case Result/Err:
        return wrap(List/Nil)
      case Result/Ok:
        fd = res_fd.val
        seeking <- IO/FS/seek(fd, start, 0)
        reading <- IO/FS/read(fd, end - start)
        closing <- IO/FS/close(fd)
        match Result/and(seeking, closing):
          case Result/Err:
            return wrap("")
          case Result/Ok:
            match reading:
              case Result/Err:
                return wrap("")
              case Result/Ok:
                return wrap(String/decode_utf8(reading.val))
      case Result/Err:
        return wrap(Result/Err(res_fd.val))

def strip_tail_(str, val):
  match str:
    case List/Nil:
      return (List/Nil, val)
    case List/Cons:
      (nxt, rem) = strip_tail_(str.tail, val)
      match rem:
        case List/Nil:
          return (List/Cons(str.head, nxt), List/Nil)
        case List/Cons:
          if rem.head == str.head:
            return (nxt, rem.tail)
          else:
            return (List/Cons(Utf8/REPLACEMENT_CHARACTER, nxt), rem.tail)

def strip_tail(str, val):
  (str, *) = strip_tail_(str, val)
  return str

def split_once_(pre, str, val):
  match str:
    case List/Nil:
      return (pre, str)
    case List/Cons:
      if str.head == val:
        return (pre, str.tail)
      else:
        return split_once_(List/concat(pre, [str.head]), str.tail, val)

def split_once(str, val):
  return split_once_(List/Nil, str, val)

def unit(str):
  match str:
    case List/Nil:
      return (List/Nil, List/Nil)
    case List/Cons:
      if str.head == 0x22:
        return split_once(str.tail, 0x22)
      elif str.head == 0x27:
        return split_once(str.tail, 0x27)
      elif str.head == 0x28:
        return split_once(str.tail, 0x29)
      elif str.head == 0x3a:
        return unit(str.tail)
      elif str.head == 0x2c:
        return unit(str.tail)
      else:
        return split_once(str, 0x2c)

def units(str):
  match str:
    case List/Nil:
      return []
    case List/Cons:
      pre, post = unit(str)
      return List/concat([String/decode_ascii(pre)], units(post))

def get_unit(arr, name):
  match arr:
    case List/Nil:
      return *
    case List/Cons:
      match arr.tail:
        case List/Nil:
          return *
        case List/Cons:
          if String/equals(arr.head, name):
            return arr.tail.head
          else:
            return get_unit(arr.tail.tail, name)

def to_num(arr):
  match arr:
    case List/Nil:
      return 0
    case List/Cons:
      return to_num(arr.tail) * 10 + (arr.head - '0')

def to_nums(arr):
  match arr:
    case List/Nil:
      return List/Nil
    case List/Cons:
      return List/Cons(to_num(arr.head), to_nums(arr.tail))

def parse_descr(descr):
  bytes = list_index(descr, 2)
  descr = strip_tail(descr, String/Cons(bytes, String/Nil))
  return (String/decode_ascii(descr), bytes - '0')

def parse_header(path):
  with IO:
    (start, end) <- header_bounds(path)
    header <- read_header(path, start, end)
    header = List/filter(header, lambda x: x != ' ')
    header = units(strip_tail(match_prefix(header, "{"), "\n},"))
    descr = parse_descr(get_unit(header, "descr"))
    fortran_order = String/equals(get_unit(header, "fortran_order"), "True")
    shape = to_nums(String/split(get_unit(header, "shape"), ','))
    return (end, descr, fortran_order, shape)

def parse_big_f8(bytes):
  match bytes:
    case List/Nil:
      return List/Nil
    case List/Cons:
      if (0x80 & bytes.head) != 0:
        sign = -1.0
      else:
        sign = +1.0
      exp = (0x7f & bytes.head) << 4
      match bytes.tail:
        case List/Nil:
          return List/Nil
        case List/Cons:
          exp = ((0xf0 & bytes.tail.head) >> 4) | exp
          exp = u24/to_f24(exp) - 0x3ff.0
          mant = bytes.tail.head & 0xf
          match bytes.tail.tail:
            case List/Nil:
              return List/Nil
            case List/Cons:
              mant = (mant << 8) | (bytes.tail.tail.head & 0xff)
              match bytes.tail.tail.tail:
                case List/Nil:
                  return List/Nil
                case List/Cons:
                  mant = (mant << 3) | ((bytes.tail.tail.tail.head & 0xe) >> 1)
                  return sign * (1.0 + u24/to_f24(mant) / 0x8000.0) * 2.0 ** exp

def flipped_end_(bytes, n, carry):
  match bytes:
    case List/Nil:
      return carry, bytes
    case List/Cons:
      if n == 0:
        return carry, bytes
      else:
        return flipped_end_(bytes.tail, n - 1, List/Cons(bytes.head, carry))

def flipped_end(bytes, n):
  return flipped_end_(bytes, n, List/Nil)

def parse_lil_f8s(bytes):
  match bytes:
    case List/Nil:
      return List/Nil
    case List/Cons:
      (res, rem) = flipped_end(bytes, 8)
      return List/Cons(parse_big_f8(res), parse_lil_f8s(rem))

def read_body(path, start):
  with IO:
    res_fd <- IO/FS/open(path, "r")
    match res_fd:
      case Result/Err:
        return wrap(List/Nil)
      case Result/Ok:
        fd = res_fd.val
        seeking <- IO/FS/seek(fd, start, 0)
        reading <- IO/FS/read(fd, 1 << 12)
        closing <- IO/FS/close(fd)
        match Result/and(seeking, closing):
          case Result/Err:
            return wrap("")
          case Result/Ok:
            match reading:
              case Result/Err:
                return wrap("")
              case Result/Ok:
                return wrap(reading.val)
      case Result/Err:
        return wrap(Result/Err(res_fd.val))

def main:
  path = "/mnt/nnd-bend/float.npy"
  with IO:
    body <- read_body(path, 128)
    return parse_lil_f8s(body)
