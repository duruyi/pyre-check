(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)


open OUnit2
open IntegrationTest


let test_check_function_redirects _ =
  assert_type_errors
    {|
      def foo(a: float) -> float:
        return abs(a)
    |}
    []


let test_check_function_parameters_with_backups _ =
  assert_type_errors "(1).__add__(1)" [];
  assert_type_errors "(1).__add__(1j)" [];
  assert_type_errors "(1).__add__(1.0)" [];
  assert_type_errors "(1).__iadd__(1.0)" []


let test_check_function_parameters _ =
  assert_type_errors
    {|
      def foo() -> None:
        int_to_int(1)
    |}
    [];

  assert_type_errors
    {|
      def foo() -> None:
        int_to_int(1.0)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `int_to_int` but got `float`.";
    ];
  assert_type_errors
    {|
      def preprocessed($renamed_i: str) -> None:
        pass
      def foo() -> None:
        preprocessed(1.0)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `str` for 1st anonymous parameter to call `preprocessed` but got `float`.";
    ];

  assert_type_errors
    {|
      def foo() -> int:
        return int_to_int(1.0)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `int_to_int` but got `float`.";
    ];

  assert_type_errors
    {|
      def foo(i) -> None:
        int_to_int(i)
    |}
    ["Missing parameter annotation [2]: Parameter `i` has no type specified."];

  assert_type_errors
    {|
      def foo(i: int, *, j: int) -> None:
        pass
    |}
    [];

  assert_type_errors
    {|
      def foo( *args, **kwargs) -> None:
        pass
    |}
    [
      "Missing parameter annotation [2]: Parameter `*args` has no type specified.";
      "Missing parameter annotation [2]: Parameter `**kwargs` has no type specified.";
    ];

  assert_type_errors
    {|
      class A:
        def foo(self) -> None:
          int_to_int(self.attribute)
    |}
    ["Undefined attribute [16]: `A` has no attribute `attribute`."];
  assert_type_errors
    {|
      class C:
       attribute: int = 1
      try:
        x = C()
      except:
        pass
      x.attribute
    |}
    ["Undefined name [18]: Global name `x` is undefined."];

  assert_type_errors
    {|
      def foo(a: typing.Union[str, None]) -> None: pass
      foo(None)
    |}
    [];

  assert_type_errors
    {|
      def foo(a: typing.Union[str, None, typing.Tuple[int, str]]) -> None:
        pass
      foo(None)
    |}
    [];

  assert_type_errors
    {|
      def foo(a: typing.Optional[int]) -> int:
        return to_int(a and int_to_str(a))
    |}
    [];

  assert_type_errors
    {|
      def foo(a: typing.Optional[int]) -> int:
        return to_int(a or int_to_str(a))
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `int_to_str` but got " ^
      "`typing.Optional[int]`.";
    ];

  assert_type_errors
    {|
      def foo(a: int) -> int:
        return a
      x: typing.Optional[int]
      foo(x if x else 1)
    |}
    [];

  assert_type_errors
    {|
      def bar(x: typing.Optional[Attributes]) -> None:
          baz(x.int_attribute if x is not None else None)

      def baz(x: typing.Optional[int]) -> None:
          pass
    |}
    [];

  assert_type_errors
    {|
      def bar(x: typing.Optional[Attributes]) -> None:
          baz(x.int_attribute if x else None)

      def baz(x: typing.Optional[int]) -> None:
          pass
    |}
    [];


  assert_type_errors
    {|
      def foo(x) -> None:
        takes_iterable(x)
    |}
    ["Missing parameter annotation [2]: Parameter `x` has no type specified."];
  assert_type_errors
    {|
      def foo(a):  # type: (typing.Optional[int]) -> None
        pass
      foo(None)
    |}
    [];
  assert_type_errors
    {|
      def foo(a):  # type: (typing.Optional[int]) -> None
        pass
      foo("hello")
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `typing.Optional[int]` for 1st anonymous parameter to call `foo` but got `str`."];
  assert_type_errors
    {|
      def foo(a):
        # type: (typing.Optional[int]) -> None
        pass
      foo("hello")
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `typing.Optional[int]` for 1st anonymous parameter to call `foo` but got `str`."];
  assert_type_errors
    {|
      def foo(a, b):
        # type: (typing.Optional[int], str) -> None
        pass
      foo(1, "hello")
    |}
    [];
  assert_type_errors
    {|
      def foo(a, b):
        # type: (typing.Optional[int], str) -> None
        pass
      foo(1, 1)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 2nd anonymous parameter to call `foo` but got `int`."]


let test_check_function_parameter_errors _ =
  assert_type_errors
    {|
      class Foo:
        attribute: str = ""
      def foo(input: Foo) -> None:
        str_float_to_int(input.attribute, input.undefined)
    |}
    ["Undefined attribute [16]: `Foo` has no attribute `undefined`."];
  assert_type_errors
    {|
      class Foo:
        attribute: str = ""
      def foo(input: Foo) -> None:
        str_float_to_int(input.undefined, input.undefined)
    |}
    [
      "Undefined attribute [16]: `Foo` has no attribute `undefined`.";
      "Undefined attribute [16]: `Foo` has no attribute `undefined`.";
    ];

  assert_type_errors
    {|
      class Foo:
        attribute: int = 1
      def foo(input: typing.Optional[Foo]) -> None:
        optional_str_to_int(input and input.attribute)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Optional[str]` for 1st anonymous parameter to call `optional_str_to_int` " ^
      "but got `typing.Optional[int]`.";
    ];
  assert_type_errors
    {|
      class Foo:
        attribute: int = 1
      def foo(input: typing.Optional[Foo]) -> None:
        optional_str_to_int(input and input.undefined)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Optional[str]` for 1st anonymous parameter to call `optional_str_to_int` " ^
      "but got `unknown`.";
      "Undefined attribute [16]: `Foo` has no attribute `undefined`.";
    ];
  assert_type_errors
    {|
      class attribute:
        ...
      class other:
        attribute: int = 1
      def foo(o: other) -> str:
        return o.attribute
    |}
    ["Incompatible return type [7]: Expected `str` but got `int`."]



let test_check_function_overloads _ =
  assert_type_errors
    {|
      class Foo:
        @overload
        def derp(self, x: int) -> int:
          pass
        @overload
        def derp(self, x: str) -> str:
          pass
        def derp(self, x: typing.Union[int, str]) -> typing.Union[int, str]:
          if isinstance(x, int):
            return 0
          else:
            return ""

      def herp(x: Foo) -> int:
        return x.derp(5)
    |}
    [];

  (* Technically invalid; all @overload stubs must be followed by implementation *)
  assert_type_errors
    {|
      class Foo:
        @overload
        def derp(self, x: int) -> int:
          pass
        @overload
        def derp(self, x: str) -> str:
          pass

      def herp(x: Foo) -> int:
        return x.derp(5)
    |}
    [];

  (* Technically invalid; @overload stubs must comprehensively cover implementation *)
  assert_type_errors
    {|
      class Foo:
        @overload
        def derp(self, x: int) -> int:
          pass
        def derp(self, x: typing.Union[int, str]) -> typing.Union[int, str]:
          if isinstance(x, int):
            return 0
          else:
            return ""

      def herp(x: Foo) -> int:
        return x.derp(5)
    |}
    [];

  assert_type_errors
    {|
      @overload
      def derp(x: int) -> int: ...
      @overload
      def derp(x: str) -> str: ...
      def derp(x: int) -> int: ...
      def derp(x: str) -> str: ...

      reveal_type(derp)
    |}
    [
      "Revealed type [-1]: Revealed type for `derp` is " ^
      "`typing.Callable(derp)[[Named(x, str)], str][[[Named(x, int)], int][[Named(x, str)], str]]`."
    ];

  assert_type_errors
    {|
      @overload
      def derp(x: int) -> int: ...
      @overload
      def derp(x: str) -> str: ...

      reveal_type(derp)
    |}
    [
      "Revealed type [-1]: Revealed type for `derp` is " ^
      "`typing.Callable(derp)[..., unknown][[[Named(x, int)], int][[Named(x, str)], str]]`."
    ];

  (* The overloaded stub will override the implementation *)
  assert_type_errors
    {|
      @overload
      def derp(x: int) -> int: ...
      def derp(x: str) -> str: ...
      @overload
      def derp(x: str) -> str: ...

      reveal_type(derp)
    |}
    [
      "Revealed type [-1]: Revealed type for `derp` is " ^
      "`typing.Callable(derp)[..., unknown][[[Named(x, int)], int][[Named(x, str)], str]]`."
    ];

  assert_type_errors
    {|
      @overload
      def derp(x: int) -> int: ...
      def derp(x: str) -> str: ...
      def derp(): ...

      reveal_type(derp)
    |}
    [
      "Revealed type [-1]: Revealed type for `derp` is " ^
      "`typing.Callable(derp)[[], unknown][[[Named(x, int)], int]]`."
    ]


let test_check_constructor_overloads _ =
  assert_type_errors
    {|
      class Class:
        @overload
        def __init__(self, i: int) -> None: ...
        @overload
        def __init__(self, s: str) -> None: ...
      def construct() -> None:
        Class(1)
        Class('asdf')
    |}
    []


let test_check_variable_arguments _ =
  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b) -> str:
        return foo ( *b )
    |}
    [
      "Missing parameter annotation [2]: Parameter `b` has no type specified.";
      "Incompatible return type [7]: Expected `str` but got `int`.";
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `foo` but got `unknown`.";
    ];

  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b: typing.Any) -> int:
        return foo ( *b )
    |}
    [
      "Missing parameter annotation [2]: Parameter `b` must have a type other than `Any`.";
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `foo` but got `unknown`.";
    ];

  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b: typing.List[str]) -> int:
        return foo ( *b )
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `foo` but got `str`.";];

  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b: typing.List[str]) -> None:
        foo('asdf', *b)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 2nd anonymous parameter to call `foo` but got `str`.";];

  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b: typing.List[str]) -> None:
        foo ( *b, 'asdf' )
    |}
    [
      "Too many arguments [19]: Call `foo` expects 2 arguments, 3 were provided.";
    ];

  assert_type_errors
    {|
      def foo(a: int, b: str) -> int:
        return 1
      def bar(b: typing.List[str]) -> None:
        foo ( *b, 1, 'asdf' )
    |}
    ["Too many arguments [19]: Call `foo` expects 2 arguments, 4 were provided."];

  assert_type_errors
    {|
      def foo(a: int, b: str) -> int:
        return 1
      def bar(b: typing.List[int]) -> None:
        foo ( *b, 'asdf' )
    |}
    ["Too many arguments [19]: Call `foo` expects 2 arguments, 3 were provided."];

  assert_type_errors
    {|
      def durp(a: int, b: str) -> int:
        return 1
      def bar(b: typing.List[int]) -> None:
        durp( *b, 1.0 )
    |}
    [
      "Too many arguments [19]: Call `durp` expects 2 arguments, 3 were provided.";
    ];

  assert_type_errors
    {|
      def foo(a: int, b: int) -> int:
        return 1
      def bar(b: typing.List[str]) -> int:
        return foo('asdf', *b)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 2nd anonymous parameter to call `foo` but got `str`.";]


let test_check_callables _ =
  (* Callable parameter checks. *)
  assert_type_errors
    {|
      def foo(callable: typing.Callable[[str], None]) -> None:
        callable(1)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 1st anonymous parameter to anoynmous call but got `int`."];

  (* Type variables & callables. *)
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(x: str) -> int:
        return 0
      def takes_parameter(f: typing.Callable[[T], int]) -> T:
        ...
      def takes_return(f: typing.Callable[[str], T]) -> T:
        ...
      def f() -> str:
        return takes_parameter(foo)
      def g() -> int:
        return takes_return(foo)
    |}
    [];

  assert_type_errors
    {|
      def foo(f: typing.Callable[..., int]) -> None:
        ...
      def i2i(x: int) -> int:
        return x
      foo(i2i)
    |}
    [];
  assert_type_errors
    {|
      def foo(f: typing.Callable[..., int]) -> None:
        ...
      def i2s(x: int) -> str:
        return ""
      foo(i2s)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Callable[..., int]` for 1st anonymous parameter to call `foo` but got " ^
      "`typing.Callable(i2s)[[Named(x, int)], str]`.";
    ];

  (* Classes with __call__ are callables. *)
  assert_type_errors
    {|
      class CallMe:
        def __call__(self, x:int) -> str:
          ...
      class CallMeToo(CallMe):
        pass

      def map(f: typing.Callable[[int], str], l: typing.List[int]) -> typing.List[str]:
        ...
      def apply(x: CallMe, y: CallMeToo) -> None:
        map(x, [])
        map(y, [])
    |}
    [];
  assert_type_errors
    {|
      class CallMe:
        def __call__(self, x: str) -> str:
          ...
      class CallMeToo(CallMe):
        pass

      def map(f: typing.Callable[[int], str], l: typing.List[int]) -> typing.List[str]:
        ...
      def apply(x: CallMe, y: CallMeToo) -> None:
        map(x, [])
        map(y, [])
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Callable[[int], str]` for 1st anonymous parameter to call `map` but got " ^
      "`CallMe`.";
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Callable[[int], str]` for 1st anonymous parameter to call `map` but got " ^
      "`CallMeToo`.";
    ];

  (* Sanity check: Callables do not subclass classes. *)
  assert_type_errors
    {|
      class CallMe:
        def __call__(self, x: int) -> str:
          ...
      def map(callable_object: CallMe, x: int) -> None:
         callable_object(x)
      def apply(f: typing.Callable[[int], str]) -> None:
        map(f, 1)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `CallMe` for 1st anonymous parameter to call `map` but got " ^
     "`typing.Callable[[int], str]`."];

  (* The annotation for callable gets expanded automatically. *)
  assert_type_errors
    {|
      def i2i(x: int) -> int:
        return 0
      def hof(c: typing.Callable) -> None:
        return
      hof(i2i)
      hof(1)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `typing.Callable[..., unknown]` for 1st anonymous parameter to call `hof` but got " ^
     "`int`."];

  assert_type_errors
    {|
      T = typing.TypeVar("T")
      def foo(x: typing.Callable[[], T]) -> T:
        ...
      def f(x: int = 1) -> str:
        return ""
      reveal_type(foo(f))
    |}
    ["Revealed type [-1]: Revealed type for `foo.(...)` is `str`."];

  (* Lambdas. *)
  assert_type_errors
    {|
      def takes_callable(f: typing.Callable[[Named(x, typing.Any)], int]) -> int:
        return 0
      takes_callable(lambda y: 0)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Callable[[Named(x, typing.Any)], int]` for 1st anonymous parameter " ^
      "to call `takes_callable` but got `typing.Callable[[Named(y, typing.Any)], int]`.";
    ];
  assert_type_errors
    {|
      def takes_callable(f: typing.Callable[[Named(x, typing.Any)], int]) -> int:
        return 0
      takes_callable(lambda y: "")
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `typing.Callable[[Named(x, typing.Any)], int]` for 1st anonymous parameter " ^
      "to call `takes_callable` but got `typing.Callable[[Named(y, typing.Any)], str]`.";
    ];

  assert_type_errors
    ~debug:false
    {|
      def exec(f: typing.Callable[[], int]) -> int:
        return f()
      def with_default(x: int = 0) -> int:
        return x
      def with_kwargs( **kwargs: int) -> int:
        return 0
      def with_varargs( *varargs: int) -> int:
        return 0
      def with_everything( *varargs: int, **kwargs: int) -> int:
        return 0
      exec(with_default)
      exec(with_kwargs)
      exec(with_varargs)
      exec(with_everything)
    |}
    []


let () =
  "signatureSelection">:::[
    "check_callables">::test_check_callables;
    "check_function_redirects">::test_check_function_redirects;
    "check_function_parameters_with_backups">::test_check_function_parameters_with_backups;
    "check_function_parameters">::test_check_function_parameters;
    "check_function_parameter_errors">::test_check_function_parameter_errors;
    "check_function_overloads">::test_check_function_overloads;
    "check_constructor_overloads">::test_check_constructor_overloads;
    "check_variable_arguments">::test_check_variable_arguments;
  ]
  |> Test.run