# Exchange

Simple stock exchange implementation with functions to create, update and delete orders see below 
for sample usage 

```
iex(1)> {:ok, pid} = Exchange.start_link()
{:ok, #PID<0.141.0>}
iex(2)> Exchange.send_instruction(pid, %{
... instruction: :new,
... side: :bid,
... price_level_index: 1, 
... price: 50.0,
... quantity: 30
... })
{:ok}
iex(3)> Exchange.send_instruction(pid, %{
... instruction: :new,
... side: :bid,
... price_level_index: 2, 
... price: 40.0,
... quantity: 40
... })
{:ok}
iex(4)> Exchange.send_instruction(pid, %{
... instruction: :new,
... side: :ask,
... price_level_index: 1, 
... price: 60.0,
... quantity: 10
... })
{:ok}
iex(5)> Exchange.send_instruction(pid, %{
... instruction: :new,
... side: :ask,
... price_level_index: 2, 
... price: 70.0,
... quantity: 10
... })
{:ok}
iex(6)> Exchange.send_instruction(pid, %{
... instruction: :update,
... side: :ask,
... price_level_index: 2, 
... price: 70.0,
... quantity: 20
... })
{:ok}
iex(7)> Exchange.send_instruction(pid, %{
... instruction: :update,
... side: :bid,
... price_level_index: 1, 
... price: 50.0,
... quantity: 40
... })
{:ok}
iex(8)> Exchange.order_book(pid, 2)
[
  %{ask_price: 60.0, ask_quantity: 10, bid_price: 50.0, bid_quantity: 40},
  %{ask_price: 70.0, ask_quantity: 20, bid_price: 40.0, bid_quantity: 40}
]
```
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exchange](https://hexdocs.pm/exchange).

