# Рекурсия

Internally, `async fn` creates a state machine type containing each
sub-`Future` being `.await`ed. This makes recursive `async fn`s a little
tricky, since the resulting state machine type has to contain itself:

```rust
// Эта функция:
async fn foo() {
    step_one().await;
    step_two().await;
}
// создаёт типы, подобные следующим:
enum Foo {
    First(StepOne),
    Second(StepTwo),
}

// А эта функция:
async fn recursive() {
    recursive().await;
    recursive().await;
}

// создаёт такие типы:
enum Recursive {
    First(Recursive),
    Second(Recursive),
}
```

This won't work-- we've created an infinitely-sized type!
The compiler will complain:

```
error[E0733]: recursion in an `async fn` requires boxing
 --> src/lib.rs:1:22
  |
1 | async fn recursive() {
  |                      ^ an `async fn` cannot invoke itself directly
  |
  = note: a recursive `async fn` must be rewritten to return a boxed future.
```

Чтобы исправить это, мы должны ввести косвенность при помощи 
`Box`. К сожалению, из-за ограничений компилятора, 
обернуть вызов `recursive()` в `Box::pin` 
не достаточно. Чтобы это заработало, мы должны сделать 
`recursive` не асинхронной функцией, которая 
возвращает `.boxed()` с `async` блоком:

```rust
{{#include ../../examples/07_05_recursion/src/lib.rs:example}}
```
