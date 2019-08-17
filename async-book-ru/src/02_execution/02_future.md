# Типаж `Future`

Типаж `Future` является центральным для асинхронного 
программирования в Rust. `Future` - это асинхронное 
вычисление, которое может производить значение (хотя значение 
может быть и пустым, например `()`). 
*Упрощённый* вариант этого типажа может выглядеть как-то 
так:

```rust
{{#include ../../examples/02_02_future_trait/src/lib.rs:simple_future}}
```

Футуры могут быть продвинуты(?) при помощи функции 
`poll`, которая продвигает их так далеко, на сколько 
это возможно. Если футура завершается, она возвращает 
`Poll::Ready(result)`. Если же она до сих пор не готова 
завершиться, то - `Poll::Pending` и предоставляет 
функцию `wake()`, которая будет вызвана, когда 
`Future` будет готова совершить прогресс(?). Когда 
`wake()` вызван, исполнитель снова вызывает у 
`Future` метод `poll`, чтобы она смогла 
продвинуться(?).

Without `wake()`, the executor would have no way of knowing when a particular
future could make progress, and would have to be constantly polling every
future. With `wake()`, the executor knows exactly which futures are ready to
be `poll`ed.

For example, consider the case where we want to read from a socket that may
or may not have data available already. If there is data, we can read it
in and return `Poll::Ready(data)`, but if no data is ready, our future is
blocked and can no longer make progress. When no data is available, we
must register `wake` to be called when data becomes ready on the socket,
which will tell the executor that our future is ready to make progress.
A simple `SocketRead` future might look something like this:

```rust
{{#include ../../examples/02_02_future_trait/src/lib.rs:socket_read}}
```

This model of `Future`s allows for composing together multiple asynchronous
operations without needing intermediate allocations. Running multiple futures
at once or chaining futures together can be implemented via allocation-free
state machines, like this:

```rust
{{#include ../../examples/02_02_future_trait/src/lib.rs:join}}
```

Здесь показано, как несколько футур могут быть запущены 
одновременно без необходимости раздельной аллокации, позволяя 
асинхронным программам быть более эффективными. Аналогично, 
несколько последовательных футур могут быть запущены одна за 
другой, как тут:

```rust
{{#include ../../examples/02_02_future_trait/src/lib.rs:and_then}}
```

Этот пример показывает, как типаж `Future` может 
использоваться для выражения асинхронного управления потоком 
без необходимости множественной аллокации объектов и глубоко 
вложенных замыканий. Оставим базовое управление потоком в 
стороне и давайте поговорим о реальном типаже 
`Future` и чем он отличается.

```rust
{{#include ../../examples/02_02_future_trait/src/lib.rs:real_future}}
```

The first change you'll notice is that our `self` type is no longer `&mut self`,
but has changed to `Pin<&mut Self>`. We'll talk more about pinning in [a later
section](../04_pinning/01_chapter.md), but for now know that it allows us to create futures that
are immovable. Immovable objects can store pointers between their fields,
e.g. `struct MyFut { a: i32, ptr_to_a: *const i32 }`. Pinning is necessary
to enable async/await.

Secondly, `wake: fn()` has changed to `&mut Context<'_>`. In `SimpleFuture`,
we used a call to a function pointer (`fn()`) to tell the future executor that
the future in question should be polled. However, since `fn()` is zero-sized,
it can't store any data about *which* `Future` called `wake`.

In a real-world scenario, a complex application like a web server may have
thousands of different connections whose wakeups should all be
managed separately. The `Context` type solves this by providing access to
a value of type `Waker`, which can be used to wake up a specific task.
