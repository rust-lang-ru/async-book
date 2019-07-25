## Для чего нужна асинхронность?

Все мы любим то, что Rust позволяет нам писать быстрые и безопасные 
приложения. Но для чего писать асинхронный код?

Асинхронный код позволяет нам запускать несколько задач 
параллельно в одном потоке ОС. Если вы ходите одновременно 
загрузить две разных web-страницы в обычном приложении, вы 
должны разделить работу между двумя разным потоками, как тут:

```rust
{{#include ../../examples/01_02_why_async/src/lib.rs:17:25}}
```

This works fine for many applications-- after all, threads were designed
to do just this: run multiple different tasks at once. However, they also
come with some limitations. There's a lot of overhead involved in the
process of switching between different threads and sharing data between
threads. Even a thread which just sits and does nothing uses up valuable
system resources. These are the costs that asynchronous code is designed
to eliminate. We can rewrite the function above using Rust's
`async`/`.await` notation, which will allow us to run multiple tasks at
once without creating multiple threads:

```rust
{{#include ../../examples/01_02_why_async/src/lib.rs:31:39}}
```

В целом, асинхронные приложения могут быть намного быстрее и 
использовать меньше ресурсов, чем соответствующая 
многопоточная реализация. Однако, есть и обратная сторона. 
Потоки изначально поддерживаются операционной системой и их 
использование не требует какой-либо специальной модели 
программирования - любая функция может создать поток и вызов 
функции, использующей поток, обычно так же прост, как вызов 
обычной функции. Тем не менее, асинхронные функции требует 
специальной поддержки со стороны языка или библиотек. В Rust, 
`async fn` создаёт асинхронную функцию, которая 
возвращает `Future`. Для выполнения тела функции, 
возвращённая `Future` должна быть завершена.

It's important to remember that traditional threaded applications can be quite
effective, and that Rust's small memory footprint and predictability mean that
you can get far without ever using `async`. The increased complexity of the
asynchronous programming model isn't always worth it, and it's important to
consider whether your application would be better served by using a simpler
threaded model.
