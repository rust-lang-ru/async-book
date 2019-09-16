# Типы возвращаемых ошибок

In a typical Rust function, returning a value of the wrong type will result
in an error that looks something like this:

```
error[E0308]: mismatched types
 --> src/main.rs:2:12
  |
1 | fn foo() {
  |           - expected `()` because of default return type
2 |     return "foo"
  |            ^^^^^ expected (), found reference
  |
  = note: expected type `()`
             found type `&'static str`
```

However, the current `async fn` support doesn't know to "trust" the return
type written in the function signature, causing mismatched or even
reversed-sounding errors. For example, the function
`async fn foo() { "foo" }` results in this error:

```
error[E0271]: type mismatch resolving `<impl std::future::Future as std::future::Future>::Output == ()`
 --> src/lib.rs:1:16
  |
1 | async fn foo() {
  |                ^ expected &str, found ()
  |
  = note: expected type `&str`
             found type `()`
  = note: the return type of a function must have a statically known size
```

The error says that it *expected* `&str` and found `()`,
which is actually the exact opposite of what you'd want. This is because the
compiler is incorrectly trusting the function body to return the correct type.

Временным решением для этой проблемы является признание 
факта, что ошибка, указывающая на сигнатуру функции с 
сообщением "expected `SomeType`, found 
`OtherType`", обычно показывает, что один или 
несколько возвращаемых вариантов не корректны.

Исправление этой ошибки отслеживается [здесь](https://github.com/rust-lang/rust/issues/54326).

## `Box<dyn Trait>`

Аналогично, так как возвращаемый тип из сигнатуры функции не 
распространяется должным образом, значение, которое 
возвращает `async fn` не правильно приводится к 
ожидаемому типу.

На практике, это означает, что возвращаемый из `async fn`
объект `Box<dyn Trait>` требует ручного 
преобразования при помощи `as` из 
`Box<MyType>` в `Box<dyn Trait>`.

Этот код приведёт к ошибке:

```
async fn x() -> Box<dyn std::fmt::Display> {
    Box::new("foo")
}
```

Временным решением для этого будет ручное преобразование с 
использованием `as`:

```
async fn x() -> Box<dyn std::fmt::Display> {
    Box::new("foo") as Box<dyn std::fmt::Display>
}
```

Исправление этой ошибки отслеживается [здесь](https://github.com/rust-lang/rust/issues/60424).
