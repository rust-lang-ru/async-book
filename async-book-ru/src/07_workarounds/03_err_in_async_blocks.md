# `?` в `async` блоках

Как и в `async fn`, `?` также может 
использоваться внутри `async` блоков. Однако 
возвращаемый тип `async` блоков явно не 
указывается. Это может привести тому, что компилятор не сможет 
определить тип ошибки `async` блока.

Например, этот код:

```rust
let fut = async {
    foo().await?;
    bar().await?;
    Ok(())
};
```

вызовет ошибку:

```
error[E0282]: type annotations needed
 --> src/main.rs:5:9
  |
4 |     let fut = async {
  |         --- consider giving `fut` a type
5 |         foo().await?;
  |         ^^^^^^^^^^^^ cannot infer type
```

Unfortunately, there's currently no way to "give `fut` a type", nor a way
to explicitly specify the return type of an `async` block.
To work around this, use the "turbofish" operator to supply the success and
error types for the `async` block:

```rust
let fut = async {
    foo().await?;
    bar().await?;
    Ok::<(), MyError>(()) // <- обратите внимание на явное указание типа
};
```
