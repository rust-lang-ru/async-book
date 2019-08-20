# Применение: создание исполнителя

Футуры Rust'a ленивы: они ничего не будут делать, если не будут активно выполняться. Один из способов довести future до завершения - это `.await` и функция `async` внутри него, но это просто подталкивает проблему на один уровень вверх: кто будет
запускать future, возвращённые из `async` функций верхнего уровня? Ответ в том,
что нам нужен исполнитель для `Future`.

Исполнители берут набор future верхнего уровня и запускают их через вызов метода `poll`, до тех пока они не завершатся. Как правило, исполнитель будет вызывать метод 
`poll` у future один раз, чтобы запустить. Когда future сообщают, что готовы продолжить вычисления при вызове метода  `wake()`, они помещаются обратно в очередь и вызов `poll` повторяется до тех пор, пока `Future` не будут завершены.

В этом разделе мы напишем нашего собственного простого исполнителя, способного одновременно запускать большое количество future верхнего уровня.

For this example, we depend on the `futures` crate for the `ArcWake` trait,
which provides an easy way to construct a `Waker`.

```toml
[package]
name = "xyz"
version = "0.1.0"
authors = ["XYZ Author"]
edition = "2018"

[dependencies]
futures-preview = "=0.3.0-alpha.17"
```

Next, we need the following imports at the top of `src/main.rs`:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:imports}}
```

Наш исполнитель будет работать, посылая задачи для запуска по каналу. Исполнитель извлечёт события из канала и запустит их. Когда задача готова выполнить больше работы (будет пробуждена), она может запланировать повторный опрос самой себя, отправив себя обратно в канал.

В этом проекте самому исполнителю просто необходим получатель для канала задачи. Пользователь получит экземпляр отправителя, чтобы он мог создавать новые future. Сами задачи - это просто future, которые могут перепланировать самих себя, поэтому мы сохраним их как future в сочетании с отправителем, который задача может использовать, чтобы запросить себя.

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:executor_decl}}
```

Давайте также добавим метод к `spawner`, чтобы было легко создавать новые `futures`.
Этот метод возьмет future, упакует и поместит его в `FutureObj`
и создаст новую `Arc<Task>` с ней внутри, которая может быть поставлена в очередь
исполнителя.

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:spawn_fn}}
```

To poll futures, we'll need to create a `Waker`.
As discussed in the [task wakeups section](./03_wakeups.md), `Waker`s are responsible
for scheduling a task to be polled again once `wake` is called. Remember that
`Waker`s tell the executor exactly which task has become ready, allowing
them to poll just the futures that are ready to make progress. The easiest way
to create a new `Waker` is by implementing the `ArcWake` trait and then using
the `waker_ref` or `.into_waker()` functions to turn an `Arc<impl ArcWake>`
into a `Waker`. Let's implement `ArcWake` for our tasks to allow them to be
turned into `Waker`s and awoken:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:arcwake_for_task}}
```

When a `Waker` is created from an `Arc<Task>`, calling `wake()` on it will
cause a copy of the `Arc` to be sent onto the task channel. Our executor then
needs to pick up the task and poll it. Let's implement that:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:executor_run}}
```

Congratulations! We now have a working futures executor. We can even use it
to run `async/.await` code and custom futures, such as the `TimerFuture` we
wrote earlier:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:main}}
```
