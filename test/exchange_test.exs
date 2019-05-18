defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange


  alias Exchange.{
    Entry,
    State
  }

  setup do 
    {:ok, pid} = Exchange.start_link([])

    {:ok, exchange: pid}
  end 

  describe "Exchange Server" do 
    test "send_instruction/2 returns {:ok} for valid event", %{exchange: pid} do
  
      event = %{
        instruction: :new,
        side: :ask,
        price_level_index: 1, 
        price: 40.9, 
        quantity: 5
      }

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

      {:ok}  = Exchange.send_instruction(pid, event) 

      %{events: [entry]} = :sys.get_state(pid) 
      
      assert entry.price_level_index == 0 
    end 
  end 
end
