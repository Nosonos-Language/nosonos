import std/[strutils, os, distros], util

var name: string
var fname*: string
var nname: seq[string]
var wdir*: string

if paramCount() >= 2:
  if detectOs(Linux):
    name = paramStr(2)
  elif detectOs(Windows):
    name = commandLineParams()[1]
  name.delete((len(name) - 5)..(len(name) - 1))
  if detectOs(Linux):
    nname = name.split("/")
  elif detectOs(Windows):
    nname = name.split("\\")
  if len(nname) == 2:
    wdir = nname[0]
    fname = nname[1]
  elif len(nname) == 1:
    wdir = ""
    fname = nname[0]

type
  Token* = enum
    # misc
    atom,
    num,
    str,
    indt,
    # one char tokens
    newline,
    colon,
    semicolon,
    comma,
    dot,
    gt, lt,
    plus, minus,
    fslash, star,
    omod,
    pipe,
    underscore,
    equ,
    lparen, rparen,
    lbrace, rbrace,
    lbrack, rbrack,
    decorate,
    # two char tokens
    constant,
    incr,
    decr,
    dictb,
    floordiv,
    dotdot,
    rarrow,
    equequ,
    gteq, lteq,
    dcolon,
    noteq,
    concat,
    cand,
    cor,
    cnot,
    # keywords
    kas,
    global,
    dataclass,
    enm,
    fun,
    put,
    ret,
    cont,
    loop,
    imprt,
    frm,
    brk,
    inmain,
    class,
    init,
    mrepr,
    meq,
    madd,
    nothing,
    isinstance,
    this,
    whle,
    match,
    cof,
    cfor,
    cin,
    btrue,
    bfalse,
    cif,
    celse,
    celif,
    pstring,
    pinteger,
    pfloat,
    pboolean,
    pbyte,
    plist,
    pset,
    pdict,
    ptuple,
    none,
    pany,
    ignoretype,
    ilgl

var
  ip*: int = 0
  rawTok*: seq[char] = @[]
  tok*: string = ""
  tokenTable*: seq[(Token, string)]
  line*: int = 1
  isEnum*: bool = false
  isDClass*: bool = false
  toCompile*: seq[string]
  toDel*: seq[string]

proc atEnd(src: seq[char]): bool =
  if ip == len(src) - 1:
    return true
  else:
    return false

proc keyword(word: string): (Token, string) =
  case word
  of "enum":
    isEnum = true
    return (Token.enm, tok)
  of "fun": return (Token.fun, tok)
  of "put": return (Token.put, tok)
  of "ret": return (Token.ret, tok)
  of "while": return (Token.whle, tok)
  of "for": return (Token.cfor, tok)
  of "true": return (Token.btrue, tok)
  of "false": return (Token.bfalse, tok)
  of "if": return (Token.cif, tok)
  of "else": return (Token.celse, tok)
  of "elif": return (Token.celif, tok)
  of "import": return (Token.imprt, tok)
  of "from": return (Token.frm, tok)
  of "in": return (Token.cin, tok)
  of "class": return (Token.class, tok)
  of "init": return (Token.init, tok)
  of "this": return (Token.this, tok)
  of "repr": return (Token.mrepr, tok)
  of "eq": return (Token.meq, tok)
  of "continue": return (Token.cont, tok)
  of "nothing": return (Token.nothing, tok)
  of "madd": return (Token.madd, tok)
  of "match": return (Token.match, tok)
  of "of": return (Token.cof, tok)
  of "loop": return (Token.loop, tok)
  of "break": return (Token.brk, tok)
  of "nameMain": return (Token.inmain, tok)
  of "isInstance": return (Token.isinstance, tok)
  of "String": return (Token.pstring, tok)
  of "Int": return (Token.pinteger, tok)
  of "Float": return (Token.pfloat, tok)
  of "Bool": return (Token.pboolean, tok)
  of "Byte": return (Token.pbyte, tok)
  of "List": return (Token.plist, tok)
  of "Set": return (Token.pset, tok)
  of "Dict": return (Token.pdict, tok)
  of "Tuple": return (Token.ptuple, tok)
  of "None": return (Token.none, tok)
  of "Any": return (Token.pany, tok)
  of "ignoreType": return (Token.ignoretype, tok)
  of "as": return (Token.kas, tok)
  of "dataclass":
    isDClass = true
    return (Token.dataclass, tok)
  of "global": return (Token.global, tok)
  of "def":
    warn("'def' was used instead of 'fun'.")
    error("Line " & $line & ": Invalid function keyword was used.")
  of "and":
    warn("'and' was used instead of '&&'.")
    error("Line " & $line & ": Invalid keyword was used.")
  of "or":
    warn("'or' was used instead of '||'.")
    error("Line " & $line & ": Invalid keyword was used.")
  of "const": return (Token.constant, tok)
  else: return (Token.atom, tok)

proc alpha(src: seq[char]): (Token, string) =
  while isAlphaAscii(src[ip]):
    rawTok.add(src[ip])
    if src[ip + 1] == '_':
      inc ip
      rawTok.add(src[ip])
    elif isDigit(src[ip + 1]):
      inc ip
      rawTok.add(src[ip])
    elif src[ip + 1] == '/' or src[ip + 1] == '\\':
      inc ip
      if detectOs(Linux):
        rawTok.add('/')
      elif detectOs(Windows):
        rawTok.add('\\')
    if not atEnd(src):
      inc ip
    if atEnd(src):
      break
  tok = toString(rawTok)
  return keyword(tok)

proc digit(src: seq[char]): (Token, string) =
  while isDigit(src[ip]):
    rawTok.add(src[ip])
    if src[ip + 1] == '.' and not (src[ip + 2] == '.'):
      inc ip
      rawTok.add(src[ip])
    if not atEnd(src):
      inc ip
    if atEnd(src):
      break
  tok = toString(rawTok)
  return (Token.num, tok)

proc lexStr(src: seq[char]): (Token, string) =
  rawTok = @[]
  if not atEnd(src):
    inc ip
  while src[ip] != '"':
    rawTok.add(src[ip])
    if not atEnd(src):
      inc ip
    elif atEnd(src):
      error("Line " & $line & ": Non-terminated string.")
  tok = toString(rawTok)
  return (Token.str, tok)

proc symbol(src: seq[char]): (Token, string) =
  case src[ip]
  of '@': return (Token.decorate, "@")
  of '(': return (Token.lparen, "(")
  of ')': return (Token.rparen, ")")
  of '"': return lexStr(src)
  of ':':
    if src[ip + 1] == ':':
      inc ip
      return (Token.dcolon, "::")
    else:
      return (Token.colon, ":")
  of ';': return (Token.semicolon, ";")
  of '{': return (Token.lbrace, "{")
  of '}': return (Token.rbrace, "}")
  of '[': return (Token.lbrack, "[")
  of ']': return (Token.rbrack, "]")
  of ',': return (Token.comma, ",")
  of '_': return (Token.underscore, "_")
  of '+':
    if src[ip + 1] == '+':
      inc ip
      return (Token.incr, "++")
    else:
      return (Token.plus, "+")
  of '-':
    if src[ip + 1] == '>':
      inc ip
      return (Token.rarrow, "->")
    elif src[ip + 1] == '-':
      inc ip
      return (Token.decr, "--")
    else:
      return (Token.minus, "-")
  of '/':
    if src[ip + 1] == '/':
      while src[ip] != '\n' and not atEnd(src):
        inc ip
      inc line
      discard
    else:
      return (Token.fslash, "/")
  of '*': return (Token.star, "*")
  of '%': return (Token.omod, "%")
  of '=':
    if src[ip + 1] == '=':
      inc ip
      return (Token.equequ, "==")
    else:
      return (Token.equ, "=")
  of '<':
    if src[ip + 1] == '=':
      inc ip
      return (Token.lteq, "<=")
    elif src[ip + 1] == '>':
      inc ip
      return (Token.concat, "<>")
    else:
      return (Token.lt, "<")
  of '>':
    if src[ip + 1] == '=':
      inc ip
      return (Token.gteq, ">=")
    elif src[ip + 1] == '/':
      inc ip
      return (Token.floordiv, ">/")
    else:
      return (Token.gt, ">")
  of '&':
    if src[ip + 1] == '&':
      inc ip
      return (Token.cand, "&&")
    else:
      error("Unknown operator '&'")
  of '|':
    if src[ip + 1] == '|':
      inc ip
      return (Token.cor, "||")
    else:
      return (Token.pipe, "|")
  of '!':
    if src[ip + 1] == '=':
      inc ip
      return (Token.noteq, "!=")
    else:
      return (Token.cnot, "!")
  of '.':
    if src[ip + 1] == '.':
      inc ip
      return (Token.dotdot, "..")
    else:
      return (Token.dot, ".")
  else: discard

proc scan*(src: seq[char]) =
  while ip < len(src) - 1:
    if isAlphaAscii(src[ip]):
      rawTok = @[]
      tokenTable.add(alpha(src))
    elif isDigit(src[ip]):
      rawTok = @[]
      tokenTable.add(digit(src))
    elif isSpaceAscii(src[ip]):
      rawTok = @[]
      if src[ip] == '\n':
        inc line
        inc ip
        tokenTable.add((newline, "nl"))
        while src[ip] == ' ':
          inc ip
          tokenTable.add((indt, "indent"))
      else:
        inc ip
    else:
      rawTok = @[]
      tokenTable.add(symbol(src))
      inc ip