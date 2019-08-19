# Вызовы задачи при помощи `Waker`

Обычно футуры не могут завершиться сразу же, как их опросили 
(вызвали метод `poll`). Когда это случается, футура 
должна быть уверена, что, когда она будет готова прогрессировать,  
она будет снова опрошена. Это решается при помощи типа 
`Waker`.

Каждый раз, когда футура опрашивается, она бывает частью 
"задачи". Задачи - это высокоуровневые футуры, с которыми 
работает исполнитель.

`Waker` обеспечивает метод `wake()`, который может быть использован, чтобы сказать исполнителю, что
соответствующая задача должна быть пробуждена. Когда вызывается `wake()`, исполнитель
знает, что задача, связанная с `Waker`, готова к выполнению, и
в будущем должна быть опрошена снова.

`Waker` also implements `clone()` so that it can be copied around and stored.

Let's try implementing a simple timer future using `Waker`.

## Applied: Build a Timer

For the sake of the example, we'll just spin up a new thread when the timer
is created, sleep for the required time, and then signal the timer future
when the time window has elapsed.

Here are the imports we'll need to get started:

```rust
{{#include ../../examples/02_03_timer/src/lib.rs:imports}}
```

Давайте определим тип нашей `future`. Нашей `future` необходим канал связи, чтобы сообщить о том что время таймера истекло и `future` должна завершиться.
В качестве канала связи между таймером и `future` мы будем использовать разделяемое значение `Arc<Mutex<..>>`.

```rust
{{#include ../../examples/02_03_timer/src/lib.rs:timer_decl}}
```

Now, let's actually write the `Future` implementation!

```rust
{{#include ../../examples/02_03_timer/src/lib.rs:future_for_timer}}
```

Просто, не так ли? Если поток установит `shared_state.completed = true`, мы закончили! В противном случае мы клонируем `Waker` для текущей задачи и сохраняем его в `shared_state.waker`. Так поток может разбудить задачу позже.

Важно отметить, что мы должны обновлять `Waker` каждый раз, когда `future` опрашивается, потому что `future` может быть перемещена в другую задачу с другим `Waker`.
Это может произойти когда футуры передаются между задачами после опроса.

Finally, we need the API to actually construct the timer and start the thread:

```rust
{{#include ../../examples/02_03_timer/src/lib.rs:timer_new}}
```

Это всё, что нам нужно для того, чтобы построить простой таймер на `future`. Теперь нам нужен исполнитель, чтобы запустить `future` на исполнение.
