# Пример `async`/`.await`

`async`/`.await` is Rust's built-in tool for writing asynchronous functions
that look like synchronous code. `async` transforms a block of code into a
state machine that implements a trait called `Future`. Whereas calling a
blocking function in a synchronous method would block the whole thread,
blocked `Future`s will yield control of the thread, allowing other
`Future`s to run.

Для создания асинхронной функции, вы можете использовать 
синтаксис `async fn`:

```rust
async fn do_something() { ... }
```

Значение, возвращённое`async fn` - `Future`. Что бы ни произошло, `Future` должна быть запущена в исполнителе.

```rust
{{#include ../../examples/01_04_async_await_primer/src/lib.rs:7:19}}
```

Внутри `async fn` вы можете использовать 
`.await` для ожидания завершения другого типа, 
реализующего типаж `Future` (например, 
полученного из другой `async fn`). В отличие от 
`block_on`, `.await` не блокирует 
текущий поток, но асинхронно ждёт завершения футуры, позволяя 
другим задачам выполняться, если в данный момент футура не 
может добиться прогресса.

Например, представим что у нас есть три `async fn`: 
`learn_song`, `sing_song` и 
`dance`:

```rust
async fn learn_song() -> Song { ... }
async fn sing_song(song: Song) { ... }
async fn dance() { ... }
```

Один из путей учиться, петь и танцевать - останавливаться на каждом из них:

```rust
{{#include ../../examples/01_04_async_await_primer/src/lib.rs:32:36}}
```

Тем не менее, в этом случае мы не получаем наилучшей 
производительности - мы одновременно делаем только одно дело! 
Очевидно, что мы должны выучить песню до того, как петь её, но 
мы можем танцевать в то же время, пока учим песню и поём её. 
Чтобы сделать это, мы создадим две отдельные 
`async fn`, которые могут запуститься параллельно:

```rust
{{#include ../../examples/01_04_async_await_primer/src/lib.rs:44:66}}
```

В этом примере, запоминание песни должно быть сделано до 
пения песни, но и запоминание и пение могут завершиться 
одновременно с танцем. Если мы используем 
`block_on(learn_song())` вместо 
`learn_song().await` в `learn_and_sing`, 
поток не может делать ничего другого, пока запущена 
`learn_song`. Из-за этого мы одновременно с этим не 
можем танцевать. Пока ожидается (`.await`) футура 
`learn_song`, мы разрешаем другим задачать 
захватить текущий поток, если `learn_song` 
заблокирована. Это делаем возможным запуск нескольких футур, 
завершающихся параллельно в одном потоке.

Теперь мы изучили основы `async`/`await`, давайте посмотрим их в работе.
