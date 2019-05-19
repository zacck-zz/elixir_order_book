defmodule Exchange.Factory do
  use ExMachina

  def delete_entry_factory do
    %{
      instruction: sequence(:role, :delete),
      side: sequence(:side, [:ask, :bid]),
      price: :rand.uniform(100),
      quantity: :rand.uniform(88),
      price_level_index: :rand.uniform(22)
    }
  end

  def entry_factory do
    %{
      instruction: sequence(:role, [:new, :update]),
      side: sequence(:side, [:ask, :bid]),
      price: :rand.uniform(100),
      quantity: :rand.uniform(88),
      price_level_index: :rand.uniform(22)
    }
  end
end
