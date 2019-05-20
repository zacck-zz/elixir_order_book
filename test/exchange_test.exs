defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange
  import Exchange.Factory

  alias Exchange.{
    Entry
  }

  setup do
    {:ok, pid} = Exchange.start_link([])

    {:ok, exchange: pid}
  end

  describe "Exchange Server" do
    test "send_instruction/2 returns {:ok} for valid event", %{exchange: pid} do
      event = build(:entry, %{instruction: :new})
      {:ok} = Exchange.send_instruction(pid, event)

      %{events: [entry]} = :sys.get_state(pid)

      assert %Entry{} = entry
    end

    test "unspecified price_level_index in an event is set to 0 in an entry", %{exchange: pid} do
      event = %{
        instruction: :new,
        side: :bid,
        price: 50.5,
        quantity: 6
      }

      {:ok} = Exchange.send_instruction(pid, event)

      %{events: [entry]} = :sys.get_state(pid)

      assert entry.price_level_index == 0
    end

    test "send_instruction/2 updates the most recent price_level", %{exchange: pid} do
      event = %{
        instruction: :new,
        side: :ask,
        price_level_index: 1,
        price: 40.9,
        quantity: 5
      }

      {:ok} = Exchange.send_instruction(pid, event)

      %{events: [entry]} = :sys.get_state(pid)

      assert entry.side == event.side
      assert entry.quantity == event.quantity

      update_event = %{
        instruction: :update,
        side: :ask,
        price_level_index: 1,
        price: 55.3,
        quantity: 7
      }

      {:ok} = Exchange.send_instruction(pid, update_event)

      %{events: [updated_entry]} = :sys.get_state(pid)

      refute updated_entry.price == entry.price
      refute updated_entry.quantity == entry.quantity

      assert updated_entry.price == update_event.price
      assert updated_entry.quantity == update_event.quantity
    end

    test "send_instruction/2 errors out if a price_level_index does not exist", %{exchange: pid} do
      event = %{
        instruction: :new,
        side: :ask,
        price_level_index: 1,
        price: 50.99,
        quantity: 7
      }

      {:ok} = Exchange.send_instruction(pid, event)

      assert %{events: [_]} = :sys.get_state(pid)

      update_event = %{
        instruction: :update,
        side: :ask,
        price_level_index: 22,
        price: 65.7,
        quantity: 9
      }

      {:error, reason: _rsn} = Exchange.send_instruction(pid, update_event)

      assert %{events: [_]} = :sys.get_state(pid)
    end

    @delete_num 4
    @top_num 7
    test "send_instruction/2 deletes a price_level", %{exchange: pid} do
      events =
        Enum.map(1..@top_num, fn n ->
          build_list(n, :entry, %{price_level_index: n, instruction: :new})
        end)
        |> Enum.reduce([], fn entries, acc -> entries ++ acc end)

      _ = Enum.map(events, fn event -> Exchange.send_instruction(pid, event) end)

      %{events: evs} = :sys.get_state(pid)

      assert Enum.count(events) == Enum.count(evs)

      event = %{
        instruction: :delete,
        price_level_index: @delete_num
      }

      {:ok} = Exchange.send_instruction(pid, event)

      %{events: new_evs} = :sys.get_state(pid)
      assert Enum.count(evs) - Enum.count(new_evs) == @delete_num

      %{price_level_index: top} =
        new_evs
        |> Enum.sort(fn a, b -> a.price_level_index < b.price_level_index end)
        |> Enum.reverse()
        |> hd()

      assert top == @top_num - 1
    end

    @bottom_num 2
    test "order_book/2 fetches an ordered book with the ask-bid spread", %{exchange: pid} do
      top_bid = build(:entry, %{side: :bid, price_level_index: @top_num + 1, instruction: :new})
      top_ask = build(:entry, %{side: :ask, price_level_index: @top_num + 1, instruction: :new})

      mid_bid = build(:entry, %{side: :bid, price_level_index: @top_num, instruction: :new})
      mid_ask = build(:entry, %{side: :ask, price_level_index: @top_num, instruction: :new})

      bottom_bid = build(:entry, %{side: :bid, price_level_index: @bottom_num, instruction: :new})
      bottom_ask = build(:entry, %{side: :ask, price_level_index: @bottom_num, instruction: :new})

      events = [top_bid, top_ask, bottom_bid, bottom_ask, mid_bid, mid_ask]

      _ =
        Enum.map(events, fn event ->
          Exchange.send_instruction(pid, event)
        end)

      books = Exchange.order_book(pid, @top_num)

      assert %{
               ask_price: bottom_ask.price,
               ask_quantity: bottom_ask.quantity,
               bid_price: bottom_bid.price,
               bid_quantity: bottom_bid.quantity
             } == hd(books)

      assert %{
               ask_price: mid_ask.price,
               ask_quantity: mid_ask.quantity,
               bid_price: mid_bid.price,
               bid_quantity: mid_bid.quantity
             } ==
               books
               |> Enum.reverse()
               |> hd()
    end
  end
end
