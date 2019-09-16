# `async` в типажах

В настоящий момент `async fn` не могут 
использоваться в типажах. Причиной является большая сложность, 
но снятие этого ограничения находится в планах на будущее.

Однако вы можете обойти это ограничение при помощи [пакета `async_trait` с crates.io](https://github.com/dtolnay/async-trait).

Note that using these trait methods will result in a heap allocation
per-function-call. This is not a significant cost for the vast majority
of applications, but should be considered when deciding whether to use
this functionality in the public API of a low-level function that is expected
to be called millions of times a second.
