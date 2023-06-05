# Закрепление

Чтобы можно было опросить футуры, они должны быть закреплены с помощью специального типа `Pin<T>`. Если вы прочитали объяснение [ типажа `Future`](../02_execution/02_future.md) в предыдущем разделе [«Выполнение `Future` и задач»](../02_execution/01_chapter.md), вы узнаете `Pin` из `self: Pin<&mut Self>` в определении метода `Future::poll`. Но что это значит, и зачем нам это нужно?

## Для чего нужно закрепление

`Pin` работает в тандеме с маркером `Unpin`. Закрепление позволяет гарантировать, что объект, реализующий `!Unpin`, никогда не будет перемещен. Чтобы понять, зачем это нужно, нужно вспомнить, как работает `async`/`.await`. Рассмотрим следующий код:

```rust,edition2018,ignore
let fut_one = /* ... */;
let fut_two = /* ... */;
async move {
    fut_one.await;
    fut_two.await;
}
```

Под капотом создаётся анонимный тип, который реализует типаж `Future` и метод `poll`:

```rust,ignore
// Тип `Future`, созданный нашим `async { ... }`-блоком
struct AsyncFuture {
    fut_one: FutOne,
    fut_two: FutTwo,
    state: State,
}

// Список состояний нашего `async`-блока
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

Когда `poll` вызывается первый раз, он опрашивает `fut_one`. Если `fut_one` не завершена, возвращается `AsyncFuture::poll`. Следующие вызовы `poll` будут начинаться там, где завершился предыдущий вызов. Этот процесс продолжается до тех пор, пока футура не будет завершена.

Однако что будет, если `async`-блок использует ссылки? Например:

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
    buf: &'a mut [u8], // указывает на `x` ниже
}

struct AsyncFuture {
     x: [u8; 128],
     read_into_buf_fut: ReadIntoBuf<'?>, // какое тут время жизни?
}
```

Здесь футура `ReadIntoBuf` содержит ссылку на другое поле нашей структуры, `x`. Однако, если `AsyncFuture` будет перемещена, положение `x` тоже будет изменено, что инвалидирует указатель, сохранённый в `read_into_buf_fut.buf`.

Закрепление футур в определённом месте памяти предотвращает эту проблему, делая безопасным создание ссылок на данные за пределами `async`-блока.

## Как устроено закрепление

Давайте попробуем понять закрепление на более простом примере. Проблема, с которой мы столкнулись выше, — это проблема, которая в конечном итоге сводится к тому, как мы обрабатываем ссылки в самореферентных типах в Rust.

Пусть наш пример будет выглядеть так:

```rust,
#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
}

impl Test {
    fn new(txt: &str) -> Self {
        Test {
            a: String::from(txt),
            b: std::ptr::null(),
        }
    }

    fn init(&mut self) {
        let self_ref: *const String = &self.a;
        self.b = self_ref;
    }

    fn a(&self) -> &str {
        &self.a
    }

    fn b(&self) -> &String {
        assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
        unsafe { &*(self.b) }
    }
}
```

`Test` предоставляет методы для получения ссылки на значение полей `a` и `b`. Поскольку `b` является ссылкой на `a`, мы храним его как указатель, так как правила заимствования Rust не позволяют нам определять его время жизни. Теперь у нас есть то, что мы называем самореферентной структурой.

Наш пример работает нормально, если мы не перемещаем какие-либо наши данные, как вы можете наблюдать в этом примере:

```rust
fn main() {
    let mut test1 = Test::new("test1");
    test1.init();
    let mut test2 = Test::new("test2");
    test2.init();

    println!("a: {}, b: {}", test1.a(), test1.b());
    println!("a: {}, b: {}", test2.a(), test2.b());

}
# #[derive(Debug)]
# struct Test {
#     a: String,
#     b: *const String,
# }
#
# impl Test {
#     fn new(txt: &str) -> Self {
#         Test {
#             a: String::from(txt),
#             b: std::ptr::null(),
#         }
#     }
#
#     // Мы должны реализовать метод `init`, чтобы сделать ссылку на себя
#     fn init(&mut self) {
#         let self_ref: *const String = &self.a;
#         self.b = self_ref;
#     }
#
#     fn a(&self) -> &str {
#         &self.a
#     }
#
#     fn b(&self) -> &String {
#         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
#         unsafe { &*(self.b) }
#     }
# }
```

Мы получили, что ожидали:

```rust,
a: test1, b: test1
a: test2, b: test2
```

Давайте посмотрим, что произойдет, если мы поменяем местами `test1` с `test2`, тем самым переместив данные:

```rust
fn main() {
    let mut test1 = Test::new("test1");
    test1.init();
    let mut test2 = Test::new("test2");
    test2.init();

    println!("a: {}, b: {}", test1.a(), test1.b());
    std::mem::swap(&mut test1, &mut test2);
    println!("a: {}, b: {}", test2.a(), test2.b());

}
# #[derive(Debug)]
# struct Test {
#     a: String,
#     b: *const String,
# }
#
# impl Test {
#     fn new(txt: &str) -> Self {
#         Test {
#             a: String::from(txt),
#             b: std::ptr::null(),
#         }
#     }
#
#     fn init(&mut self) {
#         let self_ref: *const String = &self.a;
#         self.b = self_ref;
#     }
#
#     fn a(&self) -> &str {
#         &self.a
#     }
#
#     fn b(&self) -> &String {
#         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
#         unsafe { &*(self.b) }
#     }
# }
```

По-наивности, мы могли полагать, что этот код напечатает `test1` дважды, как здесь:

```rust,
a: test1, b: test1
a: test1, b: test1
```

But instead we get:

```rust,
a: test1, b: test1
a: test1, b: test2
```

Указатель на `test2.b` по-прежнему указывает на старое местоположение, которое сейчас находится внутри `test1`. Структура больше не является самореферентной, она содержит указатель на поле в другом объекте. Это означает, что мы больше не можем рассчитывать, что время жизни `test2.b` будет привязано к времени жизни `test2` .

If you're still not convinced, this should at least convince you:

```rust
fn main() {
    let mut test1 = Test::new("test1");
    test1.init();
    let mut test2 = Test::new("test2");
    test2.init();

    println!("a: {}, b: {}", test1.a(), test1.b());
    std::mem::swap(&mut test1, &mut test2);
    test1.a = "I've totally changed now!".to_string();
    println!("a: {}, b: {}", test2.a(), test2.b());

}
# #[derive(Debug)]
# struct Test {
#     a: String,
#     b: *const String,
# }
#
# impl Test {
#     fn new(txt: &str) -> Self {
#         Test {
#             a: String::from(txt),
#             b: std::ptr::null(),
#         }
#     }
#
#     fn init(&mut self) {
#         let self_ref: *const String = &self.a;
#         self.b = self_ref;
#     }
#
#     fn a(&self) -> &str {
#         &self.a
#     }
#
#     fn b(&self) -> &String {
#         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
#         unsafe { &*(self.b) }
#     }
# }
```

The diagram below can help visualize what's going on:

**Из. 1: До и после замены** ![swap_problem](https://github.com/rust-lang-ru/async-book/blob/master/async-book-ru/src/assets/swap_problem.jpg?raw=true)

It's easy to get this to show undefined behavior and fail in other spectacular ways as well.

## Как использовать закрепление

Let's see how pinning and the `Pin` type can help us solve this problem.

The `Pin` type wraps pointer types, guaranteeing that the values behind the pointer won't be moved if it is not implementing `Unpin`. For example, `Pin<&mut T>`, `Pin<&T>`, `Pin<Box<T>>` all guarantee that `T` won't be moved if `T: !Unpin`.

У большинства типов нет проблем с перемещением, так как они реализуют типаж `Unpin`. Указатели на типы `Unpin` можно свободно помещать в `Pin` или извлекать из него. Например, `u8` реализует `Unpin`, поэтому `Pin<&mut u8>` ведет себя так же, как обычный `&mut u8`.

Однако типы, которые нельзя переместить после закрепления, имеют маркер `!Unpin`. Футуры, созданные с помощью async/await, являются примером этого.

### Закрепление на стеке

Back to our example. We can solve our problem by using `Pin`. Let's take a look at what our example would look like if we required a pinned pointer instead:

```rust,
use std::pin::Pin;
use std::marker::PhantomPinned;

#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
    _marker: PhantomPinned,
}


impl Test {
    fn new(txt: &str) -> Self {
        Test {
            a: String::from(txt),
            b: std::ptr::null(),
            _marker: PhantomPinned, // Делаем наш тип  `!Unpin`
        }
    }

    fn init(self: Pin<&mut Self>) {
        let self_ptr: *const String = &self.a;
        let this = unsafe { self.get_unchecked_mut() };
        this.b = self_ptr;
    }

    fn a(self: Pin<&Self>) -> &str {
        &self.get_ref().a
    }

    fn b(self: Pin<&Self>) -> &String {
        assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
        unsafe { &*(self.b) }
    }
}
```

Закрепление объекта на стеке всегда будет `unsafe`, если наш тип реализует `!Unpin`. Вы можете использовать такой крейт, как [`pin_utils`](https://docs.rs/pin-utils/), чтобы избежать написания собственного `unsafe` кода при закреплении в стеке.

Ниже мы закрепляем объекты `test1` и `test2` на стеке:

```rust
pub fn main() {
    // test1 безопасен для перемещения, пока мы не инициализировали его
    let mut test1 = Test::new("test1");
    // Обратите внимание, как мы затенили `test1` для предотвращения повторного доступа к нему
    let mut test1 = unsafe { Pin::new_unchecked(&mut test1) };
    Test::init(test1.as_mut());

    let mut test2 = Test::new("test2");
    let mut test2 = unsafe { Pin::new_unchecked(&mut test2) };
    Test::init(test2.as_mut());

    println!("a: {}, b: {}", Test::a(test1.as_ref()), Test::b(test1.as_ref()));
    println!("a: {}, b: {}", Test::a(test2.as_ref()), Test::b(test2.as_ref()));
}
# use std::pin::Pin;
# use std::marker::PhantomPinned;
#
# #[derive(Debug)]
# struct Test {
#     a: String,
#     b: *const String,
#     _marker: PhantomPinned,
# }
#
#
# impl Test {
#     fn new(txt: &str) -> Self {
#         Test {
#             a: String::from(txt),
#             b: std::ptr::null(),
#             // Делаем наш тип `!Unpin`
#             _marker: PhantomPinned,
#         }
#     }
#
#     fn init(self: Pin<&mut Self>) {
#         let self_ptr: *const String = &self.a;
#         let this = unsafe { self.get_unchecked_mut() };
#         this.b = self_ptr;
#     }
#
#     fn a(self: Pin<&Self>) -> &str {
#         &self.get_ref().a
#     }
#
#     fn b(self: Pin<&Self>) -> &String {
#         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
#         unsafe { &*(self.b) }
#     }
# }
```

Теперь, если мы попытаемся переместить наши данные, мы получим ошибку компиляции:

```rust,
pub fn main() {
    let mut test1 = Test::new("test1");
    let mut test1 = unsafe { Pin::new_unchecked(&mut test1) };
    Test::init(test1.as_mut());

    let mut test2 = Test::new("test2");
    let mut test2 = unsafe { Pin::new_unchecked(&mut test2) };
    Test::init(test2.as_mut());

    println!("a: {}, b: {}", Test::a(test1.as_ref()), Test::b(test1.as_ref()));
    std::mem::swap(test1.get_mut(), test2.get_mut());
    println!("a: {}, b: {}", Test::a(test2.as_ref()), Test::b(test2.as_ref()));
}
# use std::pin::Pin;
# use std::marker::PhantomPinned;
#
# #[derive(Debug)]
# struct Test {
#     a: String,
#     b: *const String,
#     _marker: PhantomPinned,
# }
#
#
# impl Test {
#     fn new(txt: &str) -> Self {
#         Test {
#             a: String::from(txt),
#             b: std::ptr::null(),
#             _marker: PhantomPinned, // Делаем наш тип `!Unpin`
#         }
#     }
#
#     fn init(self: Pin<&mut Self>) {
#         let self_ptr: *const String = &self.a;
#         let this = unsafe { self.get_unchecked_mut() };
#         this.b = self_ptr;
#     }
#
#     fn a(self: Pin<&Self>) -> &str {
#         &self.get_ref().a
#     }
#
#     fn b(self: Pin<&Self>) -> &String {
#         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
#         unsafe { &*(self.b) }
#     }
# }
```

Система типов не позволяет нам перемещать данные, как показано здесь:

```
error[E0277]: `PhantomPinned` cannot be unpinned
   --> src\test.rs:56:30
    |
56  |         std::mem::swap(test1.get_mut(), test2.get_mut());
    |                              ^^^^^^^ within `test1::Test`, the trait `Unpin` is not implemented for `PhantomPinned`
    |
    = note: consider using `Box::pin`
note: required because it appears within the type `test1::Test`
   --> src\test.rs:7:8
    |
7   | struct Test {
    |        ^^^^
note: required by a bound in `std::pin::Pin::<&'a mut T>::get_mut`
   --> <...>rustlib/src/rust\library\core\src\pin.rs:748:12
    |
748 |         T: Unpin,
    |            ^^^^^ required by this bound in `std::pin::Pin::<&'a mut T>::get_mut`
```

> Важно отметить, что закрепление на стеке всегда будет зависеть от гарантий, которые вы даете при написании `unsafe`. Хотя мы знаем, что *указатель* `&'a mut T` закреплен на время жизни `'a`, мы не можем знать, перемещаются ли данные, на которые указывает `&'a mut T`, после окончания `'a`. Если это произойдет, это нарушит контракт Pin.
>
> Ошибка, которую легко сделать, это забыть затенить исходную переменную, так как вы можете удалить `Pin` и переместить данные после `&'a mut T`, как показано ниже (что нарушает контракт Pin):
>
> ```rust
> fn main() {
>    let mut test1 = Test::new("test1");
>    let mut test1_pin = unsafe { Pin::new_unchecked(&mut test1) };
>    Test::init(test1_pin.as_mut());
>
>    drop(test1_pin);
>    println!(r#"test1.b points to "test1": {:?}..."#, test1.b);
>
>    let mut test2 = Test::new("test2");
>    mem::swap(&mut test1, &mut test2);
>    println!("... and now it points nowhere: {:?}", test1.b);
> }
> # use std::pin::Pin;
> # use std::marker::PhantomPinned;
> # use std::mem;
> #
> # #[derive(Debug)]
> # struct Test {
> #     a: String,
> #     b: *const String,
> #     _marker: PhantomPinned,
> # }
> #
> #
> # impl Test {
> #     fn new(txt: &str) -> Self {
> #         Test {
> #             a: String::from(txt),
> #             b: std::ptr::null(),
> #             // Делаем наш тип `!Unpin`
> #             _marker: PhantomPinned,
> #         }
> #     }
> #
> #     fn init<'a>(self: Pin<&'a mut Self>) {
> #         let self_ptr: *const String = &self.a;
> #         let this = unsafe { self.get_unchecked_mut() };
> #         this.b = self_ptr;
> #     }
> #
> #     fn a<'a>(self: Pin<&'a Self>) -> &'a str {
> #         &self.get_ref().a
> #     }
> #
> #     fn b<'a>(self: Pin<&'a Self>) -> &'a String {
> #         assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
> #         unsafe { &*(self.b) }
> #     }
> # }
> ```

### Закрепление на куче

Закрепление типа `!Unpin` на куче дает нашим данным постоянный адрес, поэтому мы знаем, что данные, на которые мы указываем, не могут перемещаться после закрепления. В отличие от закрепления на стеке, мы знаем, что данные будут закреплены на время жизни объекта.

```rust,
use std::pin::Pin;
use std::marker::PhantomPinned;

#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
    _marker: PhantomPinned,
}

impl Test {
    fn new(txt: &str) -> Pin<Box<Self>> {
        let t = Test {
            a: String::from(txt),
            b: std::ptr::null(),
            _marker: PhantomPinned,
        };
        let mut boxed = Box::pin(t);
        let self_ptr: *const String = &boxed.a;
        unsafe { boxed.as_mut().get_unchecked_mut().b = self_ptr };

        boxed
    }

    fn a(self: Pin<&Self>) -> &str {
        &self.get_ref().a
    }

    fn b(self: Pin<&Self>) -> &String {
        unsafe { &*(self.b) }
    }
}

pub fn main() {
    let test1 = Test::new("test1");
    let test2 = Test::new("test2");

    println!("a: {}, b: {}",test1.as_ref().a(), test1.as_ref().b());
    println!("a: {}, b: {}",test2.as_ref().a(), test2.as_ref().b());
}
```

Некоторые функции требуют, чтобы футуры, с которыми они работают, были `Unpin`. Чтобы использовать `Future` или `Stream`, которые не являются `Unpin`, с функцией, требующей `Unpin`-тип, вам сначала нужно закрепить значение с помощью `Box::pin`, создав `Pin<Box<T>>`, или макроса `pin_utils::pin_mut!`, создав `Pin<&mut T>`. `Pin<Box<Fut>>` и `Pin<&mut Fut>` могут использоваться как футуры, и оба реализуют `Unpin`.

For example:

```rust,edition2018,ignore
use pin_utils::pin_mut; // `pin_utils` -- это удобный крейт из crates.io

// Функций принимает `Future`, реализующую `Unpin`.
fn execute_unpin_future(x: impl Future<Output = ()> + Unpin) { /* ... */ }

let fut = async { /* ... */ };
execute_unpin_future(fut); // Ошибка: `fut` не реализует типаж `Unpin`

// Закрепление с `Box`:
let fut = async { /* ... */ };
let fut = Box::pin(fut);
execute_unpin_future(fut); // OK

// Закрепление с `pin_mut!`:
let fut = async { /* ... */ };
pin_mut!(fut);
execute_unpin_future(fut); // OK
```

## Summary

1. Если `T: Unpin` (что по умолчанию), то `Pin<'a, T>` полностью эквивалентен `&'a mut T`. Другими словами: `Unpin` означает, что этот тип можно перемещать, даже если он закреплен, поэтому `Pin` не повлияет на такой тип.

2. Преобразование `&mut T` в закрепленный T требует unsafe, если `T: !Unpin`.

3. Большинство типов стандартной библиотеки реализуют `Unpin`. То же самое касается большинства "обычных" типов, с которыми вы сталкиваетесь в Rust. Тип `Future`, сгенерированный с помощью async/await, является исключением из этого правила.

4. Вы можете добавить `!Unpin` к типу в nightly версии с помощью флага опции или добавив `std::marker::PhantomPinned` к вашему типу в стабильной версии.

5. Вы можете закрепить данные на стеке или на куче.

6. Для закрепления объекта `!Unpin` на стеке требуется `unsafe`

7. Закрепление объекта `!Unpin` на куче не требует `unsafe`, для этого есть сокращение `Box::pin`.

8. Для закреплённых данных, где `T: !Unpin`, вы должны поддерживать инвариант, что их память не будет аннулирована или переназначена *с момента закрепления до вызова drop*. Это важная часть *контракта pin*.
