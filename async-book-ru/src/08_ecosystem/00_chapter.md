# Асинхронная экосистема

На данный момент Rust предоставляет только самое необходимое для написание асинхронного кода. Важно отметить, что исполнители, задачи, реакторы, комбинаторы и низкоуровневая I/O функциональность не предоставляется стандартной библиотекой. Но асинхронные экосистемы, предоставляемые сообществом, восполняют эти пробелы.

The Async Foundations Team is interested in extending examples in the Async Book to cover multiple runtimes. If you're interested in contributing to this project, please reach out to us on [Zulip](https://rust-lang.zulipchat.com/#narrow/stream/201246-wg-async-foundations.2Fbook).

## Асинхронные среды выполнения

Асинхронные среды выполнения — это библиотеки, используемые для выполнения асинхронных приложений. Среды выполнения обычно объединяют *реактор* с одним или несколькими *исполнителями*. Реакторы предоставляют механизмы подписки на внешние события, такие как асинхронный ввод-вывод, межпроцессное взаимодействие и таймеры. В асинхронной среде выполнения подписчиками обычно являются футуры, представляющие низкоуровневые операции ввода-вывода. Исполнители занимаются планированием и выполнением задач. Они отслеживают запущенные и приостановленные задачи, опрашивают футуры до завершения и пробуждают задачи, когда они могут продвигаться вперед. Слово «исполнитель» часто используется как синоним «среды выполнения». Здесь мы используем слово «экосистема» для описания среды выполнения с совместимыми чертами и функциями.

## Community-Provided Async Crates

### The Futures Crate

The [`futures` crate](https://docs.rs/futures/) contains traits and functions useful for writing async code. This includes the `Stream`, `Sink`, `AsyncRead`, and `AsyncWrite` traits, and utilities such as combinators. These utilities and traits may eventually become part of the standard library.

У `futures` есть собственный исполнитель, но нет собственного реактора, поэтому он не поддерживает выполнение асинхронного ввода-вывода или футур по таймеру. По этой причине он не считается полной средой выполнения. Обычная практика — использовать утилиты из `futures` с исполнителем из другого крейта.

### Popular Async Runtimes

В стандартной библиотеке нет асинхронной среды выполнения, и ни одна из них официально не рекомендована. Следующие крейты содержат популярные среды выполнения.

- [Tokio](https://docs.rs/tokio/): A popular async ecosystem with HTTP, gRPC, and tracing frameworks.
- [async-std](https://docs.rs/async-std/): A crate that provides asynchronous counterparts to standard library components.
- [smol](https://docs.rs/smol/): небольшая упрощенная асинхронная среда выполнения. Предоставляет `Async`, который можно использовать обёртки таких структур, как `UnixStream` или `TcpListener`.
- [fuchsia-async](https://fuchsia.googlesource.com/fuchsia/+/master/src/lib/fuchsia-async/): An executor for use in the Fuchsia OS.

## Determining Ecosystem Compatibility

Not all async applications, frameworks, and libraries are compatible with each other, or with every OS or platform. Most async code can be used with any ecosystem, but some frameworks and libraries require the use of a specific ecosystem. Ecosystem constraints are not always documented, but there are several rules of thumb to determine whether a library, trait, or function depends on a specific ecosystem.

Любой асинхронный код, взаимодействующий с асинхронным вводом-выводом, таймерами, межпроцессным взаимодействием или задачами, обычно зависит от конкретного асинхронного исполнителя или реактора. Весь другой асинхронный код, такой как асинхронные выражения, комбинаторы, типы синхронизации и потоки, обычно не зависит от экосистемы, при условии, что внутренние футуры также не зависят от экосистемы. Перед началом проекта рекомендуется изучить соответствующие асинхронные платформы и библиотеки, чтобы обеспечить совместимость с выбранной вами средой выполнения и друг с другом.

Notably, `Tokio` uses the `mio` reactor and defines its own versions of async I/O traits, including `AsyncRead` and `AsyncWrite`. On its own, it's not compatible with `async-std` and `smol`, which rely on the [`async-executor` crate](https://docs.rs/async-executor), and the `AsyncRead` and `AsyncWrite` traits defined in `futures`.

Конфликты зависимостей иногда можно разрешить с помощью прослойки, которая позволит вызывать код для одной среды выполнения из другой. Например, [`async_compat`](https://docs.rs/async_compat) обеспечивает прослойку между `Tokio` и другими средами выполнения.

Libraries exposing async APIs should not depend on a specific executor or reactor, unless they need to spawn tasks or define their own async I/O or timer futures. Ideally, only binaries should be responsible for scheduling and running tasks.

## Single Threaded vs Multi-Threaded Executors

Async executors can be single-threaded or multi-threaded. For example, the `async-executor` crate has both a single-threaded `LocalExecutor` and a multi-threaded `Executor`.

Многопоточный исполнитель выполняет несколько задач одновременно. Это может значительно ускорить выполнение с множеством задач, но синхронизация данных между задачами обычно обходится довольно дорого. При выборе между однопоточной и многопоточной средой выполнения рекомендуется измерять производительность вашего приложения.

Задачи могут выполняться в текущем потоке либо в отдельном. Асинхронные среды выполнения часто предоставляют возможность запуска задач в отдельном потоке, но даже тогда задачи всё равно должны быть неблокирующими. Чтобы задачи были выполнены на многопоточном исполнителе, они должны реализовывать типаж `Send`. Некоторые среды выполнения позволяют порождать задачи без `Send`, что гарантирует выполнение каждой задачи в потоке, который её породил. Они также могут предоставлять функции для порождения блокирующих задач в отдельных потоках, что полезно для запуска блокирующего синхронного кода из других библиотек.
