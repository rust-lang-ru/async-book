## Состояние асинхронности в Rust

Со временем, асинхронная экосистема Rust претерпела 
значительные изменения, и теперь трудно понять какие 
инструменты использовать, каким библиотеками уделять внимание 
и какую документацию читать. Тем не менее, недавно был 
стабилизирован типаж `Future` стандартной 
библиотеки и на подходе стабилизация `async`
/`await`. Таким образом, система находится в 
процессе перехода к недавно стабилизированному API, после чего 
мешанина будет значительно уменьшена.

At the moment, however, the ecosystem is still undergoing rapid development
and the asynchronous Rust experience is unpolished. Most libraries still
use the 0.1 definitions of the `futures` crate, meaning that to interoperate
developers frequently need to reach for the `compat` functionality from the
0.3 `futures` crate. The `async`/`await` language feature is still new.
Important extensions like `async fn` syntax in trait methods are still
unimplemented, and the current compiler error messages can be difficult to
parse.

Это говорит о том, что Rust на пути к более эффективной и 
эргономичной поддержке асинхронного программирования и если 
вы не боитесь изменений, наслаждайтесь погружением в мир 
асинхронного программирования в Rust!
