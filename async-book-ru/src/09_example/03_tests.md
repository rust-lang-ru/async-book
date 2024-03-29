# Тестирование TCP-сервера

Давайте перейдём к тестированию нашей функции `handle_connection`.

Во-первых, нам нужен `TcpStream` для работы. В сквозном или интеграционном тесте мы можем захотеть установить реальное TCP-соединение для проверки нашего кода. Одна из стратегий для этого — запустить приложение на порту 0 `localhost`. Порт 0 не является допустимым портом UNIX, но он подойдёт для тестирования. Операционная система выберет для нас открытый порт TCP.

Вместо этого в этом примере мы напишем модульный тест для обработчика соединения, чтобы проверить, что для входных данных возвращаются правильные ответы. Чтобы наш модульный тест оставался изолированным и детерминированным, мы замокаем `TcpStream`.

Для начала, мы изменим сигнатуру `handle_connection`, чтобы упростить тестирование. `handle_connection` на самом деле не требует `async_std::net::TcpStream`, а требует любую структуру, которая реализует `async_std::io::Read`, `async_std::io::Write` и `marker::Unpin`. Изменив сигнатуру типа таким образом, мы сможем передать мок для тестирования.

```rust,ignore
use async_std::io::{Read, Write};

async fn handle_connection(mut stream: impl Read + Write + Unpin) {
```

Далее давайте создадим мок `TcpStream`, который реализует нужные типажи. Во-первых, давайте реализуем типаж `Read` с методом `poll_read`. Наш мок `TcpStream` будет содержать некоторые данные, которые копируются в буфер чтения, и мы вернём `Poll::Ready`, чтобы показать, что чтение завершено.

```rust,ignore
{{#include ../../examples/09_05_final_tcp_server/src/main.rs:mock_read}}
```

Наша реализация `Write` очень похожа, хотя нам нужно написать три метода: `poll_write`, `poll_flush` и `poll_close`. `poll_write` скопирует входные данные в мок `TcpStream` и вернёт `Poll::Ready` после завершения. Для сброса или закрытия мока `TcpStream` не требуется никакой работы, поэтому `poll_flush` и `poll_close` могут просто вернуть `Poll::Ready` .

```rust,ignore
{{#include ../../examples/09_05_final_tcp_server/src/main.rs:mock_write}}
```

Наконец, нашему моку нужно будет реализовать `Unpin`, что означает, что его местоположение в памяти может быть безопасно перемещено. Для получения дополнительной информации о закреплении и `Unpin` см. [раздел о закреплении](../04_pinning/01_chapter.md) .

```rust,ignore
{{#include ../../examples/09_05_final_tcp_server/src/main.rs:unpin}}
```

Теперь мы готовы протестировать функцию `handle_connection`. После настройки `MockTcpStream`, содержащего некоторые начальные данные, мы можем запустить `handle_connection`, используя атрибут `#[async_std::test]`, аналогично тому, как мы использовали `#[async_std::main]`. Чтобы убедиться, что `handle_connection` работает должным образом, мы проверим, что в `MockTcpStream` были записаны правильные данные на основе его исходного содержимого.

```rust,ignore
{{#include ../../examples/09_05_final_tcp_server/src/main.rs:test}}
```
