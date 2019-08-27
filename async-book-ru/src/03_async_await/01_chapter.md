# `async`/`await`

В [первой главе](../01_getting_started/04_async_await_primer.md) мы бросили беглый вгляд на `async`/`.await` и использовали
это чтобы построить простой сервер. В этой главе мы обсудим  `async`/`.await` более подробно, объясняя, как это работает и как `async` код отличается от
традиционных программ на Rust.

`async`/`.await` - это специальный синтаксис Rust, который позволяет передавать контроль выполнения в потоке другому коду, пока ожидается окончание завершения, а не блокировать поток.

There are two main ways to use `async`: `async fn` and `async` blocks.
Each returns a value that implements the `Future` trait:

```rust
{{#include ../../examples/03_01_async_await/src/lib.rs:async_fn_and_block_examples}}
```

Как мы видели в первой главе, `async` блоки и другие `futures` ленивы:
они ничего не делают, пока их не запустят. Наиболее распространённый способ запуска `Future` -
это `.await`. Когда `.await` вызывается на `Future`, он пытается завершить выполнение до конца. Если `Future` заблокирована, то контроль будет передан текущему потоку. Чтобы добиться большего прогресса, будет выбрана верхняя `Future` исполнителя, позволяя `.await` продолжить работу.

## `async` Lifetimes

В отличие от традиционных функций, `async fn`, которые принимают ссылки или другие
не-`'static` аргументы, возвращают `Future`, которая ограничена временем жизни
аргумента:

```rust
{{#include ../../examples/03_01_async_await/src/lib.rs:lifetimes_expanded}}
```

Это означает, что `future`, возвращаемая из `async fn`, должен быть вызван `.await`
до тех пор пока её не-`'static` аргументы все ещё действительны. В общем
случае, вызов `.await` у `future` сразу после вызова функции
(как в `foo(&x).await`) это не проблема. Однако, если сохранить `future`
или отправить её в другую задачу или поток, это может быть проблемой.

One common workaround for turning an `async fn` with references-as-arguments
into a `'static` future is to bundle the arguments with the call to the
`async fn` inside an `async` block:

```rust
{{#include ../../examples/03_01_async_await/src/lib.rs:static_future_with_borrow}}
```

By moving the argument into the `async` block, we extend its lifetime to match
that of the `Future` returned from the call to `foo`.

## `async move`

`async` блоки и замыкания позволяют использовать ключевое слово `move`, как обычные
замыкания. `async move` блок получает владение переменными со ссылками, позволяя им пережить текущую область, но отказывая им в возможности делиться этими 
переменными с другим кодом:

```rust
{{#include ../../examples/03_01_async_await/src/lib.rs:async_move_examples}}
```

## `.await`ing on a Multithreaded Executor

Обратите внимание, что при использовании `Future` в многопоточном исполнителе, `Future` может перемещаться
между потоками, поэтому любые переменные, используемые в телах `async`, должны иметь возможность перемещаться
между потоками, как и любой `.await` потенциально может привести к переключению на новый поток.

Это означает, что не безопасно использовать `Rc`, `&RefCell` или любые другие типы, 
не реализующие типаж `Send` (включая ссылки на типы, которые не реализуют типаж `Sync`).

(Caveat: it is possible to use these types so long as they aren't in scope
during a call to `.await`.)

Точно так же не очень хорошая идея держать традиционную `non-futures-aware` блокировку
через `.await`, так как это может привести к блокировке пула потоков: одна задача может
получить объект блокировки, вызвать `.await` и передать управление исполнителю, разрешив другой задаче совершить попытку взять блокировку, что и вызовет взаимоблокировку. Чтобы избежать этого, используйте `Mutex` из `futures::lock`, а не из `std::sync`.
