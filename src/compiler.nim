import std/[strutils, os, distros], util, scan

var
  indentLevel: int = 0
  prevIndent: int = 0
  listLevel: int = 0
  parenLevel: int = 0
  lhs, rhs: string
  isIf: bool = false
  isWhile: bool = false
  isFun: bool = false # Nosonos is fun, but this variable clearly isn't.
  isBrace: bool = false
  isMatch: bool = false
  isFor: bool = false
  isLoop: bool = false
  globalTable: seq[string]
  constTable: seq[string]
  varTable: seq[string]
  localTable: seq[string]
  etypes: seq[Token] = @[
    Token.pany, Token.pboolean,
    Token.pbyte, Token.pdict,
    Token.pfloat, Token.pinteger,
    Token.plist, Token.pset,
    Token.pstring, Token.ptuple
  ]
  types: seq[Token] = @[
    Token.atom, Token.str,
    Token.num, Token.btrue,
    Token.bfalse, Token.underscore,
    Token.pstring,
    Token.pinteger, Token.pfloat,
    Token.pboolean, Token.pbyte,
    Token.plist, Token.pset,
    Token.pdict, Token.ptuple,
    Token.none, Token.pany,
    Token.put, Token.newline,
    Token.rbrack, Token.lbrack,
    Token.lparen, Token.rparen
  ]

proc lookahead(tbl: seq[(Token, string)], expect: Token, index: int): bool =
  if index != len(tbl) - 1:
    if tbl[index + 1][0] == expect:
      return true
    else:
      return false

proc lookback(tbl: seq[(Token, string)], expect: Token, index: int): bool =
  if tbl[index - 1][0] == expect:
    return true
  else:
    return false

proc compile*(tbl: seq[(Token, string)] = tokenTable): string =
  var output: string = "# Generated by Nosonos.\n\n"
  if isEnum or isDClass:
    output = output & "# Start Nosonos import #\n"
    if isEnum:
      output = output & "from enum import Enum, auto\n"
    if isDClass:
      output = output & "from dataclasses import dataclass\n"
    output = output & "# End Nosonos import #\n\n"
  isDClass = false
  isEnum = false
  for i in 0..len(tbl) - 1:
    case tbl[i][0]
    of Token.kas: output = output & " as "
    of Token.incr:
      if lookback(tbl, Token.atom, i) and not constTable.contains(tbl[i - 1][1]):
        lhs = tbl[i - 1][1]
        output = output & lhs & " += 1"
      elif lookback(tbl, Token.atom, i) and constTable.contains(tbl[i - 1][1]):
        error("Line " & $line & ": Cannot increment a constant. Try declaring it as a normal variable instead.")
      else:
        error("Line " & $line & ": Invalid type for increment operator.")
    of Token.decr:
      if lookback(tbl, Token.atom, i) and not constTable.contains(tbl[i - 1][1]):
        lhs = tbl[i - 1][1]
        output = output & lhs & " -= 1"
      elif lookback(tbl, Token.atom, i) and constTable.contains(tbl[i - 1][1]):
        error("Line " & $line & ": Cannot decrement a constant. Try declaring it as a normal variable instead.")
      else:
        error("Line " & $line & ": Invalid type for decrement operator.")
    of Token.global:
      if lookahead(tbl, Token.atom, i):
        globalTable.add(tbl[i + 1][1])
        varTable.add(tbl[i + 1][1])
      else:
        error("Line " & $line & ": Improper use of the 'global' keyword.")
    of Token.dataclass:
      if not lookahead(tbl, Token.atom, i):
        error("Line " & $line & ": Expected a name after 'dataclass'.")
      else:
        isDClass = true
        if indentLevel > 0:
          warn("Line " & $line & ": Dataclasses should only be declared in toplevel.")
        rhs = tbl[i + 1][1]
        output = output & "@dataclass\n" & repeat(' ', indentLevel) & "class " & rhs
    of Token.enm:
      if not lookahead(tbl, Token.atom, i):
        error("Line " & $line & ": Expected a name after 'enum'.")
      else:
        isEnum = true
        if indentLevel > 0:
          warn("Line " & $line & ": Enums should only be declared in toplevel.")
        rhs = tbl[i + 1][1]
        output = output & "class " & rhs & "(Enum)"
    of Token.constant:
      if lookahead(tbl, Token.atom, i):
        if constTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Cannot redefine an already defined constant.")
        constTable.add(tbl[i + 1][1])
        output = output & tbl[i + 1][1].toUpperAscii
      else:
        error("Line " & $line & ": Expected an atom after the constant keyword.")
    of Token.local:
      if lookahead(tbl, Token.atom, i):
        if constTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Cannot redefine an already defined constant.")
        elif varTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Cannot convert a normal variable to a local.")
        localTable.add(tbl[i + 1][1])
        output = output & tbl[i + 1][1]
      else:
        error("Line " & $line & ": Expected an atom after the local keyword.")
    of Token.defvar:
      if lookahead(tbl, Token.atom, i):
        if constTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Cannot redefine a defined constant to a normal variable.")
        if not varTable.contains(tbl[i + 1][1]):
          varTable.add(tbl[i + 1][1])
          output = output & tbl[i + 1][1]
        elif varTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Variable '" & tbl[i + 1][1] & "' has already been defined.")
        elif localTable.contains(tbl[i + 1][1]):
          error("Line " & $line & ": Cannot convert a local into a normal variable.")
      else:
        error("Line " & $line & ": Expected an atom after variable keyword.")
    of Token.decorate: output = output & "@"
    of Token.ignoretype: output = output & " # type: ignore"
    of Token.pany: output = output & "any"
    of Token.plist: output = output & "list"
    of Token.pset: output = output & "set"
    of Token.pdict: output = output & "dict"
    of Token.ptuple: output = output & "tuple"
    of Token.none: output = output & "None"
    of Token.dcolon: output = output & " -> "
    of Token.pbyte: output = output & "bytes"
    of Token.pstring: output = output & "str"
    of Token.pinteger: output = output & "int"
    of Token.pfloat: output = output & "float"
    of Token.pboolean: output = output & "bool"
    of Token.underscore:
      if lookahead(tbl, Token.rarrow, i):
        continue
      else:
        output = output & "_"
    of Token.isinstance: output = output & "isinstance"
    of Token.inmain: output = output & "if __name__ == '__main__'"
    of Token.brk: output = output & "break"
    of Token.match:
      if lookahead(tbl, Token.atom, i):
        isMatch = true
        output = output & "match "
      else:
        error("Line " & $line & ": Expected an atom after 'match' statement.")
    of Token.cof: output = output & "case "
    of Token.put:
      if lookahead(tbl, Token.lparen, i):
        output = output & "print"
      else:
        error("Line " & $line & ": Expected a parenthese after print statement.")
    of Token.fun:
      if lookahead(tbl, Token.atom, i) or lookahead(tbl, Token.init, i) or lookahead(tbl, Token.mrepr, i) or lookahead(tbl, Token.meq, i):
        isFun = true # It's fun now.
        output = output & "def "
      else:
        error("Line " & $line & ": Expected an atom after function definition.")
    of Token.ret: output = output & "return "
    of Token.cont: output = output & "continue"
    of Token.whle:
      isWhile = true
      output = output & "while "
    of Token.cfor:
      if lookahead(tbl, Token.atom, i):
        isFor = true
        output = output & "for "
      else:
        error("Line " & $line & ": Expected an atom after 'for' keyword.")
    of Token.cin: output = output & " in "
    of Token.class:
      if indentLevel > 0:
        warn("Line " & $line & ": Classes should only be declared in toplevel.")
      output = output & "class "
    of Token.init:
      if lookahead(tbl, Token.lparen, i):
        output = output & "__init__"
      else:
        error("Line " & $line & ": Expected parenthese after 'init' keyword.")
    of Token.mrepr:
      if lookahead(tbl, Token.lparen, i):
        output = output & "__repr__"
      else:
        error("Line " & $line & ": Expected parenthese after 'repr' keyword.")
    of Token.meq:
      if lookahead(tbl, Token.lparen, i):
        output = output & "__eq__"
      else:
        error("Line " & $line & ": Expected parenthese after 'eq' keyword.")
    of Token.this: output = output & "self"
    of Token.loop:
      isLoop = true
      output = output & "while True"
    of Token.imprt:
      if i != 0:
        if tbl[i - 1][1] == fname:
          error("Cannot import a module with the same name as the source file.")
        elif lookback(tbl, Token.atom, i):
          continue
      else:
        if tbl[i + 1][1] == fname:
          error("Cannot import a module with the same name as the source file.")
        if lookahead(tbl, Token.atom, i):
          if not fileExists(wdir & "/" & tbl[i + 1][1] & ".nos") and not lookahead(tbl, Token.star, i) and detectOs(Linux):
            continue
          elif not fileExists(wdir & "\\" & tbl[i + 1][1] & ".nos") and not lookahead(tbl, Token.star, i) and detectOs(Windows):
            continue
          else:
            if detectOs(Linux) and toCompile.contains(wdir & "/" & tbl[i + 1][1] & "_nos"):
              output = output & tbl[i + 1][1] & "_nos"
              continue
            elif detectOs(Windows) and toCompile.contains(wdir & "\\" & tbl[i + 1][1] & "_nos"):
              output = output & tbl[i + 1][1] & "_nos"
              continue
            else:
              toCompile.add(tbl[i + 1][1])
              toDel.add(tbl[i + 1][1])
              output = output & tbl[i + 1][1] & "_nos"
        else:
          error("Line " & $line & ": Expected a module name after 'import' statement.")
    of Token.frm:
      if lookahead(tbl, Token.atom, i):
        rhs = tbl[i + 1][1]
        if not fileExists(wdir & "/" & tbl[i + 1][1] & ".nos") and detectOs(Linux):
          output = output & "from " & rhs & " "
        elif not fileExists(wdir & "\\" & tbl[i + 1][1] & ".nos") and detectOs(Windows):
          output = output & "from " & rhs & " "
        else:
          if detectOs(Linux) and toCompile.contains(wdir & "/" & tbl[i + 1][1] & "_nos"):
            output = output & "from " & rhs & "_nos "
            continue
          elif detectOs(Windows) and toCompile.contains(wdir & "\\" & tbl[i + 1][1] & "_nos"):
            output = output & "from " & rhs & "_nos "
            continue
          else:
            toCompile.add(tbl[i + 1][1])
            toDel.add(tbl[i + 1][1])
            output = output & "from " & rhs & "_nos "
      else:
        error("Line " & $line & ": Expected an atom after 'from' statement.")
    of Token.btrue: output = output & "True"
    of Token.bfalse: output = output & "False"
    of Token.nothing: output = output & "pass"
    of Token.madd: output = output & "__add__"
    of Token.cif:
      isIf = true
      output = output & "if "
    of Token.celse:
      isIf = true
      output = output & "else"
    of Token.celif:
      isIf = true
      output = output & "elif "
    of Token.cand: output = output & " and "
    of Token.cor: output = output & " or "
    of Token.lparen:
      inc parenLevel
      output = output & "("
    of Token.rparen:
      dec parenLevel
      output = output & ")"
    of Token.lbrack:
      inc listLevel
      output = output & "["
    of Token.rbrack:
      dec listLevel
      output = output & "]"
    of Token.pipe: output = output & " | "
    of Token.atom:
      if i != 0:
        if lookback(tbl, Token.imprt, i):
          if detectOs(Linux) and fileExists(wdir & "/" & tbl[i][1] & ".nos"):
            continue
          elif detectOs(Windows) and fileExists(wdir & "\\" & tbl[i][1] & ".nos"):
            continue
          else:
            output = output & "import " & tbl[i][1]
        elif lookback(tbl, Token.frm, i):
          if detectOs(Linux) and fileExists(wdir & "/" & tbl[i][1] & ".nos"):
            continue
          elif detectOs(Windows) and fileExists(wdir & "\\" & tbl[i][1] & ".nos"):
            continue
          else:
            continue
        elif lookahead(tbl, Token.rarrow, i):
          continue
        elif lookback(tbl, Token.rarrow, i):
          continue
        elif lookback(tbl, Token.enm, i):
          continue
        elif lookback(tbl, Token.dataclass, i):
          continue
        elif lookback(tbl, Token.global, i):
          output = output & tbl[i][1]
        elif lookahead(tbl, Token.incr, i) or lookahead(tbl, Token.decr, i):
          continue
        elif lookback(tbl, Token.incr, i) or lookback(tbl, Token.decr, i):
          continue
        elif lookback(tbl, Token.constant, i):
          continue
        elif lookback(tbl, Token.defvar, i):
          continue
        elif lookback(tbl, Token.local, i):
          continue
        else:
          if globalTable.contains(tbl[i][1]) and not (parenLevel > 0 or isEnum or listLevel > 0 or isIf or isWhile or isFun):
            output = output & "global " & tbl[i][1] & "\n" & repeat(' ', indentLevel) & tbl[i][1]
          elif constTable.contains(tbl[i][1]):
            output = output & tbl[i][1].toUpperAscii
          else:
            output = output & tbl[i][1]
      else:
        if lookahead(tbl, Token.constant, i):
          continue
        elif lookahead(tbl, Token.rarrow, i):
          continue
        elif lookahead(tbl, Token.incr, i) or lookahead(tbl, Token.decr, i):
          continue
        else:
          output = output & tbl[i][1]
    of Token.num:
      if i != 0:
        if lookahead(tbl, Token.dotdot, i):
          continue
        elif lookback(tbl, Token.dotdot, i):
          continue
        elif lookahead(tbl, Token.rarrow, i):
          continue
        elif lookback(tbl, Token.rarrow, i):
          continue
        else:
          output = output & tbl[i][1]
      else:
        output = output & tbl[i][1]
    of Token.str:
      if i != 0:
        if lookahead(tbl, Token.rarrow, i):
          continue
        elif lookback(tbl, Token.rarrow, i):
          continue
        else:
          output = output & "\"" & tbl[i][1] & "\""
      else:
        output = output & "\"" & tbl[i][1] & "\""
    of Token.colon:
      isIf = false
      isWhile = false
      isMatch = false
      isFor = false
      isLoop = false
      output = output & ": "
    of Token.semicolon: output = output & "; "
    of Token.comma: output = output & ", "
    of Token.plus:
      if i != 0:
        if not (lookahead(tbl, Token.num, i) or lookahead(tbl, Token.atom, i)) and not (lookback(tbl, Token.num, i) or lookback(tbl, Token.atom, i)):
          error("Line " & $line & ": Unsupported types for addition operator.")
        else:
          output = output & " + "
    of Token.concat:
      if i != 0:
        if not (lookahead(tbl, Token.str, i) or lookahead(tbl, Token.atom, i)) and not (lookback(tbl, Token.str, i) or lookback(tbl, Token.atom, i)):
          error("Line " & $line & ": Unsupported types for concatenation operator.")
        else:
          output = output & " + "
    of Token.minus: output = output & " - "
    of Token.fslash: output = output & " / "
    of Token.star:
      if lookback(tbl, Token.imprt, i):
        output = output & "import *"
      else:
        output = output & " * "
    of Token.omod: output = output & " % "
    of Token.floordiv: output = output & " // "
    of Token.rarrow:
      if types.contains(tbl[i - 1][0]):
        if lookback(tbl, Token.str, i):
          lhs = "\"" & tbl[i - 1][1] & "\""
        else:
          lhs = tbl[i - 1][1]
        if types.contains(tbl[i + 1][0]) or tbl[i + 1][0] == Token.lbrace or tbl[i + 1][0] == Token.ret:
          if lookahead(tbl, Token.str, i):
            rhs = " \"" & tbl[i + 1][1] & "\""
          else:
            if tbl[i + 1][1] != "put" and tbl[i + 1][1] != "ret" and tbl[i + 1][1] != "nl" and tbl[i + 1][1] != "{":
              rhs = tbl[i + 1][1]
          if lookahead(tbl, Token.lbrace, i):
            output = output & "case " & lhs
          else:
            output = output & "case " & lhs & ": " & rhs
        else:
          error("Line " & $line & ": Invalid match parameter on right hand side.")
      else:
        error("Line " & $line & ": Invalid match parameter on left hand side.")
    of Token.equ:
      if isFun or isWhile or isIf or isEnum or isDClass or isMatch or isFor or isLoop:
        if isWhile or isIf or isMatch or isFor or isLoop:
          error("Line " & $line & ": You should use ':' for while, if, else, elif, for, loop, and match blocks.")
        output = output & ": "
        isFun = false # Aww man.
        isIf = false
        isWhile = false
        isEnum = false
        isDClass = false
        isMatch = false
        isFor = false
        isLoop = false
      elif etypes.contains(tbl[i - 1][0]):
        if not (tbl[i - 3][0] == Token.atom):
          error("Line " & $line & ": Cannot assign to a value that is not an atom.")
        elif constTable.contains(tbl[i - 3][1]):
          if not (tbl[i - 4][0] == Token.constant):
            error("Line " & $line & ": Cannot redefine a constant.")
          output = output & " = "
        elif not varTable.contains(tbl[i - 3][1]) and not localTable.contains(tbl[i - 3][1]):
          error("Line " & $line & ": Variable '" & tbl[i - 3][1] & "' is undefined.")
        else:
          output = output & " = "
      elif lookback(tbl, Token.atom, i):
        if constTable.contains(tbl[i - 1][1]):
          if not (tbl[i - 2][0] == Token.constant):
            error("Line " & $line & ": Cannot redefine a constant.")
          output = output & " = "
        elif not varTable.contains(tbl[i - 1][1]) and not localTable.contains(tbl[i - 1][1]):
          error("Line " & $line & ": Variable '" & tbl[i - 1][1] & "' is undefined.")
        else:
          output = output & " = "
      else:
        output = output & " = "
    of Token.equequ: output = output & " == "
    of Token.lt: output = output & " < "
    of Token.gt: output = output & " > "
    of Token.lteq: output = output & " <= "
    of Token.gteq: output = output & " >= "
    of Token.noteq: output = output & " != "
    of Token.cnot: output = output & "not "
    of Token.dotdot:
      if lookback(tbl, Token.num, i) and lookahead(tbl, Token.num, i):
        lhs = tbl[i - 1][1]
        rhs = tbl[i + 1][1]
        if listLevel > 0:
          var tmp: string = ""
          for j in parseInt(lhs)..parseInt(rhs):
            if j != parseInt(rhs):
              tmp = tmp & $j & ", "
            else:
              tmp = tmp & $j
          output = output & tmp
        else:
          output = output & "range(" & lhs & ", " & $(parseInt(rhs) + 1) & ")"
      else:
        error("Line " & $line & ": Expected a number.")
    of Token.dot: output = output & "."
    of Token.lbrace:
      isBrace = true
      output = output & "{"
    of Token.rbrace:
      isBrace = false
      output = output & "}"
    of Token.indt:
      output = output & " "
      inc indentLevel
    of Token.comment: inc line
    of Token.newline:
      inc line
      prevIndent = indentLevel
      indentLevel = 0
      output = output & "\n"
    else: error("Line " & $line & ": '" & $tbl[i] & "' is not defined or is defined elsewhere")
  tokenTable = @[]
  return output