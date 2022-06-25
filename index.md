The Nosonos programming language is a language that compiles down to Python, for easy use with other Python libraries and such.

Nosonos' syntax is inspired by [Kotlin](https://kotlinlang.org), [Rust](https://www.rust-lang.org), [Nim](https://nim-lang.org), and [Prowl](https://github.com/UberPyro/prowl).

The current version is 0.7.3.

## Supported Systems
Linux and Windows.

Windows support is highly experimental and may constantly break, proceed with caution.

Linux binaries are built and tested on Fedora 36, and Windows binaries are built and tested on Windows 10.

## Fun Stuff
The longest lived series of Nosonos were 0.1.x and 0.4.x, both going up to 0.1.5 and 0.4.5. Just a little fun fact.

The longest lived bug in Nosonos was a compilation/scan bug, where nothing would work if you weren't in the same directory as your sources. Started in 0.1.0 and finally ended in 0.6.0. That's 23 releases until it was fixed.

## Code Samples
Hello World:
```kotlin
fun helloFun() :: None =
  put("Hello, world! I'm in a function!")

put("Hello, world!")
helloFun()
```

Fib (w/ memoization):
```kotlin
from functools import cache

@cache
fun fib(n: Int) :: Int =
  if n <= 1:
    ret n
  ret fib(n - 1) + fib(n - 2)

fun main() :: None =
  for i in 0..399:
    put(i, fib(i))
  put("Done")

nameMain:
  main()
```

Adding Numbers:
```kotlin
fun addTwo(a: Int, b: Int) :: Int =
  ret a + b

fun addThree(a: Int, b: Int, c: Int) :: Int =
  ret a + b + c

x: Int = 7
y: Int = 10
z: Int = 9

put(addTwo(x, y))
put(addThree(x, y, z))
```

Matching and Loops:
```kotlin
fun m(arg: Int) :: String =
  match arg:
    0 -> ret "zero"
    1 -> ret "one"
    _ -> ret "none"

loop:
  uin: Int = Int(input("> "))
  put(m(uin))
```

Quicksort:
```kotlin
fun qs(arr: List) :: List =
  less: List = []
  pivotList: List = []
  more: List = []
  if len(arr) <= 1:
    ret arr
  else:
    pivot = arr[0]
    for i in arr:
      if i < pivot:
        less.append(i)
      elif i > pivot:
        more.append(i)
      else:
        pivotList.append(i)
    less = qs(less)
    more = qs(more)
    ret less + pivotList + more

a = [ 4, 65, 2,
      -31, 0, 99,
      83, 782, 1 ]

a = qs(a)

put(a)
```

Calculator:
```kotlin
fun add() :: Int =
  a: Int = Int(input("[a]> "))
  b: Int = Int(input("[b]> "))
  ret a + b

fun sub() :: Int =
  a: Int = Int(input("[a]> "))
  b: Int = Int(input("[b]> "))
  ret a - b

fun mul() :: Int =
  a: Int = Int(input("[a]> "))
  b: Int = Int(input("[b]> "))
  ret a * b

fun div() :: Float =
  a: Float = Float(input("[a]> "))
  b: Float = Float(input("[b]> "))
  ret a / b

fun fdiv() :: Int =
  a: Int = Int(input("[a]> "))
  b: Int = Int(input("[b]> "))
  ret a >/ b

fun mod() :: Int =
  a: Int = Int(input("[a]> "))
  b: Int = Int(input("[b]> "))
  ret a % b

fun main() :: None =
  put("Available operators:")
  put("add")
  put("sub")
  put("mul")
  put("div")
  put("fdiv")
  put("mod")
  loop:
    uin: String = input("> ")
    match uin:
      "add" -> put(add())
      "sub" -> put(sub())
      "mul" -> put(mul())
      "div" -> put(div())
      "fdiv" -> put(fdiv())
      "mod" -> put(mod())
      "ops" ->
        put("Available operators:")
        put("add")
        put("sub")
        put("mul")
        put("div")
        put("fdiv")
        put("mod")
      _ -> put("Error: Not allowed.")

nameMain:
  main()
```

Dataclass:
```kotlin
dataclass Employee =
  name: String
  id: String
  age: Int
  city: String

employeeOne = Employee("Bob", "bobd867", 27, "Columbus")

put(employeeOne)
```

Increment and Decrement:
```kotlin
x = 10
put(x)
x++
put(x)
++x
put(x)
x--
put(x)
--x
put(x)

x = 0

for i in 0..9:
  put(x)
  ++x
```

Globals:
```kotlin
global x = "awesome"

fun test() =
  x = "fantastic"

put("Nosonos is " <> x)

test()

put("Nosonos is " <> x)
```

Double Dot:
```kotlin
test = [0..9]

put(test)
```

Constants:
```kotlin
// Define a constant.
test := 10

// Print the value of the constant.
put(test)

// Work with the constant
x = 7
put(x + test)
x = 5
put(x + test)

// Work with several constants.
foo := "Hello, "
bar := "world!"
put(foo <> bar)
```