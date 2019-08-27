# Закрепление (pinning)

To poll futures, they must be pinned using a special type called
`Pin<T>`. If you read the explanation of [the `Future` trait](../02_execution/02_future.md) in the
previous section ["Executing `Future`s and Tasks"](../02_execution/01_chapter.md), you'll recognise
`Pin` from the `self: Pin<&mut Self>` in the `Future:poll` method's definition.
But what does it mean, and why do we need it?

## Для чего перемещение

Pinning makes it possible to guarantee that an object won't ever be moved.
To understand why this is necessary, we need to remember how `async`/`.await`
works. Consider the following code:

```rust
let fut_one = ...;
let fut_two = ...;
async move {
    fut_one.await;
    fut_two.await;
}
```

Под капотом, он создаёт два анонимных типа, которые реализуют типаж `Future`,
предоставляющий метод `poll`, выглядящий примерно так:

```rust
// Тип `Future`, созданный нашим `async { ... }` блоком
struct AsyncFuture {
    fut_one: FutOne,
    fut_two: FutTwo,
    state: State,
}

// Список возможных состояний нашего `async` блока
enum State {
    AwaitingFutOne,
    AwaitingFutTwo,
    Done,
}

impl Future for AsyncFuture {
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
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

When `poll` is first called, it will poll `fut_one`. If `fut_one` can't
complete, `AsyncFuture::poll` will return. Future calls to `poll` will pick
up where the previous one left off. This process continues until the future
is able to successfully complete.

Однако, что будет, если `async` блок использует ссылки?
Например:

```rust
async {
    let mut x = [0; 128];
    let read_into_buf_fut = read_into_buf(&mut x);
    read_into_buf_fut.await;
    println!("{:?}", x);
}
```

Во что скомпилируется эта структура?

```rust
struct ReadIntoBuf<'a> {
    buf: &'a mut [u8], // указывает на `x` далее
}

struct AsyncFuture {
    x: [u8; 128],
    read_into_buf_fut: ReadIntoBuf<'?>, // какое тут время жизни?
}
```

Here, the `ReadIntoBuf` future holds a reference into the other field of our
structure, `x`. However, if `AsyncFuture` is moved, the location of `x` will
move as well, invalidating the pointer stored in `read_into_buf_fut.buf`.

Pinning futures to a particular spot in memory prevents this problem, making
it safe to create references to values inside an `async` block.

## Как использовать закрепление

Тип `Pin` оборачивает указатель на другие типы, 
гарантируя, что значение за указателем не будет перемещено. 
Например, `Pin<&mut T>`, `Pin<&T>`,
`Pin<Box<T>>` - все гарантируют, что положение 
`T` останется неизменным.

У большинства типов нет проблем с перемещением. Эти типы 
реализуют типаж `Unpin`. Указатели на 
`Unpin`-типы могут свободно помещаться в 
`Pin` или извлекаться из него. Например, тип 
`u8` реализует `Unpin`, таким образом 
`Pin<&mut T>` ведёт себя также, как и 
`&mut T`.

Some functions require the futures they work with to be `Unpin`. To use a
`Future` or `Stream` that isn't `Unpin` with a function that requires
`Unpin` types, you'll first have to pin the value using either
`Box::pin` (to create a `Pin<Box<T>>`) or the `pin_utils::pin_mut!` macro
(to create a `Pin<&mut T>`). `Pin<Box<Fut>>` and `Pin<&mut Fut>` can both be
used as futures, and both implement `Unpin`.

Например:

```rust
use pin_utils::pin_mut; // `pin_utils` - удобный пакет, доступный на crates.io

// Функция, принимающая `Future`, которая реализует `Unpin`.
fn execute_unpin_future(x: impl Future<Output = ()> + Unpin) { ... }

let fut = async { ... };
execute_unpin_future(fut); // Ошибка: `fut` не реализует типаж `Unpin`

// Закрепление с помощью `Box`:
let fut = async { ... };
let fut = Box::pin(fut);
execute_unpin_future(fut); // OK

// Закрепление с помощью `pin_mut!`:
let fut = async { ... };
pin_mut!(fut);
execute_unpin_future(fut); // OK
```
