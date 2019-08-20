# Применение: создание исполнителя

Футуры Rust'a ленивы: они ничего не будут делать, если не будут активно выполняться. Один из способов довести future до завершения - это `.await` и функция `async` внутри него, но это просто подталкивает проблему на один уровень вверх: кто будет
запускать future, возвращённые из `async` функций верхнего уровня? Ответ в том,
что нам нужен исполнитель для `Future`.

Исполнители берут набор future верхнего уровня и запускают их через вызов метода `poll`, до тех пока они не завершатся. Как правило, исполнитель будет вызывать метод 
`poll` у future один раз, чтобы запустить. Когда future сообщают, что готовы продолжить вычисления при вызове метода  `wake()`, они помещаются обратно в очередь и вызов `poll` повторяется до тех пор, пока `Future` не будут завершены.

В этом разделе мы напишем нашего собственного простого исполнителя, способного одновременно запускать большое количество future верхнего уровня.

В этом примере мы зависим от пакета `futures`, в котором определен типаж `ArcWake`. Данный типаж предоставляет простой способ для создания `Waker`.

```toml
[package]
name = "xyz"
version = "0.1.0"
authors = ["XYZ Author"]
edition = "2018"

[dependencies]
futures-preview = "=0.3.0-alpha.17"
```

Дальше, мы должны в верней части файла `src/main.rs` разместить следующий список зависимостей:

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

Чтобы опросить `futures`, нам нужно создать `Waker`.
Как описано в разделе [задачи пробуждения](./03_wakeups.md), `Waker`s отвечают
за планирование задач, которые будут опрошены снова после вызова `wake`. `Waker`s сообщают исполнителю, какая именно задача завершилась, позволяя
опрашивать как раз те `futures`, которые готовы к продолжению выполнения. Простой способ
создать новый `Waker`, необходимо реализовать типаж `ArcWake`, а затем использовать
`waker_ref` или `.into_waker()` функции для преобразования `Arc & lt;impl ArcWake & gt;`
в `Waker`. Давайте реализуем `ArcWake` для наших задач, чтобы они были
превращены в `Waker`s и могли пробуждаться:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:arcwake_for_task}}
```

Когда `Waker` создается на основе `Arc<Task>`, вызывая `wake()` это
вызовит отправку копии `Arc` в канал задач. Тогда нашуму исполнителю 
нужно подобрать задание и опросить его. Давайте реализуем это:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:executor_run}}
```

Поздравляю! Теперь у нас есть работающий исполнитель `futures`. Мы даже можем использовать его
для запуска `async/.await` кода и пользовательских `futures`, таких как `TimerFuture` которую мы описали ранее:

```rust
{{#include ../../examples/02_04_executor/src/lib.rs:main}}
```