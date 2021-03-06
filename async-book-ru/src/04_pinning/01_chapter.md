# Закрепление (pinning)

Чтобы опросить футуры, они должны быть закреплены с помощью специального типа `Pin<T>`. Если вы прочитали объяснение [`Future`] в предыдущем разделе [«Выполнение `Future` и задач»], вы узнаете `Pin` из `self: Pin<&mut Self>` в определении метода `Future::poll`. Но что это значит, и зачем нам это нужно?

## Для чего нужно закрепление

Закрепление даёт возможность гарантировать, что объект не будет перемещён. Чтобы понять почему это важно, нам надо помнить как работает `async`/`.await`. Рассмотрим следующий код:

```rust,edition2018,ignore
let fut_one = /* ... */;
let fut_two = /* ... */;
async move {
    fut_one.await;
    fut_two.await;
}
```

Под капотом, он создаёт анонимный тип, который реализует типаж `Future`, предоставляющий метод `poll`, выглядящий примерно так:

```rust,ignore
// The `Future` type generated by our `async { ... }` block
struct AsyncFuture {
    fut_one: FutOne,
    fut_two: FutTwo,
    state: State,
}

// List of states our `async` block can be in
enum State {
    AwaitingFutOne,
    AwaitingFutTwo,
    Done,
}

impl Future for AsyncFuture {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        loop {
            match self.state {
                State::AwaitingFutOne => match self.fut_one.poll(..) {
                    Poll::Ready(()) => self.state = State::AwaitingFutTwo,
                    Poll::Pending => return Poll::Pending,
                }
                State::AwaitingFutTwo => match self.fut_two.poll(..) {
                    Poll::Ready(()) => self.state = State::Done,
                    Poll::Pending => return Poll::Pending,
                }
                State::Done => return Poll::Ready(()),
            }
        }
    }
}
```

Когда `poll` вызывается первый раз, он опрашивает `fut_one`. Если `fut_one` не завершена, возвращается `AsyncFuture::poll`. Следующие вызовы `poll` будут начинаться там, где завершился предыдущий вызов. Этот процесс продолжается до тех пор, пока  `future` не сможет завершиться.

Однако, что будет, если `async` блок использует ссылки? Например:

```rust,edition2018,ignore
async {
    let mut x = [0; 128];
    let read_into_buf_fut = read_into_buf(&mut x);
    read_into_buf_fut.await;
    println!("{:?}", x);
}
```

Во что скомпилируется эта структура?

```rust,ignore
struct ReadIntoBuf<'a> {
    buf: &'a mut [u8], // указывает на `x` далее
}

struct AsyncFuture {
     x: [u8; 128],
     read_into_buf_fut: ReadIntoBuf<'?>, // какое тут время жизни?
}
```

Здесь `future` `ReadIntoBuf` содержит ссылку на другое  поле нашей структуры, `x`. Однако, если `AsyncFuture` будет перемещена, положение `x` тоже будет изменено, что инвалидирует указатель, сохранённый в `read_into_buf_fut.buf`.

Закрепление футур в определённом месте памяти предотвращает эту проблему, делая безопасным создание ссылок на данные за пределами `async` блока.

## Как использовать закрепление

Тип `Pin` оборачивает указатель на другие типы, гарантируя, что значение за указателем не будет перемещено. Например, `Pin<&mut T&gt;`, `Pin<&T&gt;`, `Pin<Box<T>&gt;` - все гарантируют, что положение  `T` останется неизменным.

У большинства типов нет проблем с перемещением. Эти типы  реализуют типаж `Unpin`. Указатели на `Unpin`-типы могут свободно помещаться в `Pin` или извлекаться из него. Например, тип `u8` реализует `Unpin`, таким образом `Pin<&mut u8>` ведёт себя также, как и `&mut u8`.

Некоторые функции требуют, чтобы футуры, с которыми они работают, были `Unpin`. Чтобы использовать `Future` или `Stream`, который не реализует `Unpin`, с функцией, которая требует `Unpin`-типы, сначала нужно закрепить значение, используя либо `Box::pin` (чтобы создать `Pin<Box<T>>`) или макрос `pin_utils::pin_mut!` (чтобы создать `Pin<&mut T>`). `Pin<Box<Fut>>` и `Pin<&mut Fut>` могут быть использованы как футура и оба реализуют `Unpin`.

Например:

```rust,edition2018,ignore
use pin_utils::pin_mut; // `pin_utils` is a handy crate available on crates.io

// A function which takes a `Future` that implements `Unpin`.
fn execute_unpin_future(x: impl Future<Output = ()> + Unpin) { /* ... */ }

let fut = async { /* ... */ };
execute_unpin_future(fut); // Error: `fut` does not implement `Unpin` trait

// Pinning with `Box`:
let fut = async { /* ... */ };
let fut = Box::pin(fut);
execute_unpin_future(fut); // OK

// Pinning with `pin_mut!`:
let fut = async { /* ... */ };
pin_mut!(fut);
execute_unpin_future(fut); // OK
```


[«Выполнение `Future` и задач»]: ../02_execution/01_chapter.md
[`Future`]: ../02_execution/02_future.md
