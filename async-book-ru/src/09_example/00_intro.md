# Финальный проект: Создание конкурентного веб-сервера с асинхронным Rust

В этой главе мы будем использовать асинхронный Rust для модификации [однопоточного веб-сервера](https://doc.rust-lang.org/book/ch20-01-single-threaded.html) из книги Rust для одновременного обслуживания запросов.

## Резюме

Вот как выглядел код в конце урока.

`src/main.rs`:

```rust
{{#include ../../examples/09_01_sync_tcp_server/src/main.rs}}
```

`hello.html`:

```html
{{#include ../../examples/09_01_sync_tcp_server/hello.html}}
```

`404.html`:

```html
{{#include ../../examples/09_01_sync_tcp_server/404.html}}
```

Если вы запустите сервер с помощью `cargo run` и посетите `127.0.0.1:7878` в своем браузере, вас встретит дружеское сообщение от Ferris!
