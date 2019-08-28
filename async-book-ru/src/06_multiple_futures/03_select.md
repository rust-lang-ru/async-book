# `select!`

Макрос `futures::select` запускает несколько `future` 
одновременно, позволяя пользователю ответить как только любая 
из `future` завершится.

```rust
{{#include ../../examples/06_03_select/src/lib.rs:example}}
```

The function above will run both `t1` and `t2` concurrently. When either
`t1` or `t2` finishes, the corresponding handler will call `println!`, and
the function will end without completing the remaining task.

The basic syntax for `select` is `<pattern> = <expression> => <code>,`,
repeated for as many futures as you would like to `select` over.

## `default => ...` и `complete => ...`

Также `select` поддерживает ветки `default` и `complete`.

Ветка `default` выполнится, если ни одна из `future`, 
переданная в `select`, не завершится. Поэтому, 
`select` с веткой `default`, всегда будет 
незамедлительно завершаться, так как `default` будет 
запущена, когда ещё ни одна `future` не готова.

`complete` branches can be used to handle the case where all futures
being `select`ed over have completed and will no longer make progress.
This is often handy when looping over a `select!`.

```rust
{{#include ../../examples/06_03_select/src/lib.rs:default_and_complete}}
```

## Взаимодействие с `Unpin` и `FusedFuture`

One thing you may have noticed in the first example above is that we
had to call `.fuse()` on the futures returned by the two `async fn`s,
as well as pinning them with `pin_mut`. Both of these calls are necessary
because the futures used in `select` must implement both the `Unpin`
trait and the `FusedFuture` trait.

`Unpin` is necessary because the futures used by `select` are not
taken by value, but by mutable reference. By not taking ownership
of the future, uncompleted futures can be used again after the
call to `select`.

Similarly, the `FusedFuture` trait is required because `select` must
not poll a future after it has completed. `FusedFuture` is implemented
by futures which track whether or not they have completed. This makes
it possible to use `select` in a loop, only polling the futures which
still have yet to complete. This can be seen in the example above,
where `a_fut` or `b_fut` will have completed the second time through
the loop. Because the future returned by `future::ready` implements
`FusedFuture`, it's able to tell `select` not to poll it again.

Заметьте, что у `stream` есть соответствующий типаж `FusedStream`. `Stream`, реализующие этот типаж 
или имеющие обёртку, созданную `.fuse()`, возвращают `FusedFuture` из их комбинаторов 
`.next()` и `.try_next()`.

```rust
{{#include ../../examples/06_03_select/src/lib.rs:fused_stream}}
```

## Concurrent tasks in a `select` loop with `Fuse` and `FuturesUnordered`

Одна довольно труднодоступная, но удобная функция - `Fuse::terminated()`, которая позволяет создавать уже 
прекращённые пустые `future`, которые в последствии могут быть заполнены другой `future`, которую надо запустить.

Это может быть удобно, когда есть задача, которую надо запустить в цикле в `select`, но которая 
создана вне этого цикла.

Обратите внимание на функцию `.select_next_some()`. Она может использоваться с `select` для запуска тех 
ветвей, которые получили от потока `Some(_)`, а не `None`.

```rust
{{#include ../../examples/06_03_select/src/lib.rs:fuse_terminated}}
```

Когда надо одновременно запустить много копий какой-либо `future`, используйте тип `FuturesUnordered`. 
Следующий пример похож на один из тех, что выше, но дождётся завершения каждой выполненной копии 
`run_on_new_num_fut`, а не остановит её при создании новой. Она также отобразит значение, возвращённое 
`run_on_new_num_fut`.

```rust
{{#include ../../examples/06_03_select/src/lib.rs:futures_unordered}}
```
