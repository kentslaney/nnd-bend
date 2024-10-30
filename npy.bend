from ./util import (list_index, reshape, shape_size)

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

def bytes_to_u24(bytes):
  match bytes:
    case List/Cons:
      return bytes_to_u24(bytes.tail) << 8 | bytes.head
    case List/Nil:
      return 0

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
                                  substr = take(minor.tail, size)
                                  start = 8 + size
                                  extra = bytes_to_u24(substr, 0)
                                  return wrap((start, start + extra))

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
    return wrap((end, descr, fortran_order, shape))

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

def read_chunks(fd, n):
  if n == 0:
    with IO:
      return wrap([])
  else:
    with IO:
      reading <- IO/FS/read(fd, 1 << 13)
      match reading:
        case Result/Err:
          return wrap([])
        case Result/Ok:
          res = parse_lil_f8s(reading.val)
          rem <- read_chunks(fd, n - 1)
          res = List/concat(res, rem)
          return wrap(res)

def read_body(path, start, n):
  with IO:
    res_fd <- IO/FS/open(path, "r")
    match res_fd:
      case Result/Err:
        return wrap(List/Nil)
      case Result/Ok:
        fd = res_fd.val
        seeking <- IO/FS/seek(fd, start, 0)
        reading <- read_chunks(fd, n)
        closing <- IO/FS/close(fd)
        match Result/and(seeking, closing):
          case Result/Err:
            return wrap("")
          case Result/Ok:
            return wrap(reading)

def parse_body(path):
  with IO:
    (end, descr, fortran_order, shape) <- parse_header(path)
    body <- read_body(path, end, shape_size(shape) / 1024 + 1)
    return wrap(reshape(body, shape))

def int_str(int):
  if int == 0:
    return ""
  else:
    return List/concat(int_str(int / 10), List/Cons((int % 10) + '0', List/Nil))

def shape_str(shape):
  match shape:
    case List/Cons:
      res = int_str(shape.head)
      rem = shape_str(shape.tail)
      match rem:
        case List/Nil:
          return res
        case List/Cons:
          return List/concat(List/concat(res, ", "), rem)
    case List/Nil:
      return List/Nil

def space_pads(n):
  if n == 0:
    return List/Nil
  else:
    return List/Cons(' ', space_pads(n - 1))

def create_header(shape: List(List(u24))):
  magic = List/Cons(0x93, npy_prefix)
  vers_size = [1, 0, 0x76, 0]
  preamble = List/concat(magic, vers_size)
  descr = "{'descr': '<u4', 'fortran_order': False, 'shape': ("
  descr = String/encode_utf8(descr)
  descr = List/concat(descr, shape_str(shape))
  iption = String/encode_utf8(")}")
  content = List/concat(preamble, List/concat(descr, iption))
  (len, content) = List/length(content)
  return List/concat(List/concat(content, space_pads(127 - len)), ['\n'])

def flatten_(data, shape):
  match shape:
    case List/Nil:
      return data
    case List/Cons:
      return List/flatten(flatten_(data, shape.tail))

def flatten(data, shape):
  match shape:
    case List/Nil:
      return data
    case List/Cons:
      return flatten_(data, shape.tail)

def to_lil_bytes(x, n):
  if n == 0:
    return List/Nil
  else:
    return List/Cons(x & 0xff, to_lil_bytes(x >> 8, n - 1))

def to_u32s(x):
  match x:
    case List/Nil:
      return List/Nil
    case List/Cons:
      return List/concat(to_lil_bytes(x.head, 4), to_u32s(x.tail))

def npy_data(data, shape):
  return List/concat(create_header(shape), to_u32s(flatten(data, shape)))

def save_npy(path, data, shape):
  with IO:
    return IO/FS/write_file(path, npy_data(data, shape))
