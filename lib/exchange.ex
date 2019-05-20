defmodule Exchange do
  @moduledoc """
  An order book implementataion, uses a GenServer to run a long running process which can handle incoming 
  instructions and as output can product an order book listing the most recent price_level asks and bids 
  depending on the level that has been provided as a filter 
  """
  @typep instruction() :: :new | :update | :delete

  @typep side() :: :ask | :bid

  @type handle_event_response() :: {:ok} | {:error, reason: term()}

  @typedoc """
  Type representing an order book event
  """
  @type event() :: %{
          instruction: instruction(),
          side: side(),
          price: float(),
          quantity: integer()
        }

  use GenServer

  defmodule State do
    @moduledoc """
    Datastructure representing our Exchange Server's state
    """
    @type t :: __MODULE__
    defstruct events: []
  end

  defmodule Entry do
    @moduledoc """
    Datastructure representing an order in our Server's Orderbook
    """
    @type t :: __MODULE__
    defstruct [:instruction, :side, :price, :quantity, price_level_index: 0]
  end

  @doc """
  Boots up our stock exhange and gets it ready to handle events 

  ## Parameters 
  opts: A keyword list of start options, at the moment these options are ignored 
  """
  @spec start_link(list()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @doc """
  Handles received events for the stock exchange it performs 
  the relevant action according to the event's instruction 

  ## Parameters 
  * `exchange` - the pid for a running exchange
  * `event` - event for the exchange to process 

  """
  @spec send_instruction(pid(), event()) :: handle_event_response()
  def send_instruction(pid, event) do
    entry = struct(Entry, event)
    GenServer.call(pid, {:handle_event, entry})
  end

  @doc """
  Handles the order book request for the stock exchange, it picks all relevant entries 
  and lists out the bid vs the asks where bids or ask are missing an atom is used to 
  represent this, i.e `:no_bid`, `no_ask`

  ## Parameters 
  * `exchange` - the pid for a running exchange 
  * `depth`- depth at which to cut off events 
  """
  @spec order_book(pid(), non_neg_integer()) :: list(Entry.t())
  def order_book(pid, depth) do
    GenServer.call(pid, {:book, depth})
  end

  @doc """
  Initializes the GenServer with a blank state and ready's the event handling
  """
  @spec init(map()) :: {:ok, State.t()}
  def init(_args) do
    {:ok, %State{}}
  end

  @doc """
  Callback to process current order book up to a given depth 
  """
  @spec handle_call({:book, integer()}, pid(), State.t()) :: list(map())
  def handle_call({:book, depth}, _pid, %{events: events} = state) do
    valid_entries =
      1..depth
      |> Enum.map(fn level -> make_entry(level, events) end)
      |> Enum.filter(fn map -> Enum.count(map) > 0 end)

    {:reply, valid_entries, state}
  end

  @doc """
  Callback to process incoming events into to the exchange
  """
  @spec handle_call({:handle_event, Entry.t()}, pid(), State.t()) :: handle_event_response()
  def handle_call({:handle_event, event}, _from, state) do
    {result, new_state} =
      case event.instruction do
        :new ->
          add_event(event, state)

        :update ->
          update_level(event, state)

        :delete ->
          delete_level(event, state)
      end

    {:reply, result, new_state}
  end

  @doc false
  @spec make_entry(integer(), list(Entry.t())) :: map()
  defp make_entry(lvl, entries) do
    result =
      [:ask, :bid]
      |> Enum.map(fn s -> entry_finder(lvl, s, entries) end)

    entry =
      case result do
        [ask: nil, bid: nil] ->
          %{}

        [ask: nil, bid: %{price: p, quantity: q}] ->
          %{ask_price: nil, ask_quantity: nil, bid_price: p, quantity: q}

        [ask: %{price: p, quantity: q}, bid: nil] ->
          %{ask_price: p, ask_quantity: q, bid_price: nil, bid_quantity: nil}

        [ask: ask, bid: bid] ->
          %{
            ask_price: ask.price,
            ask_quantity: ask.quantity,
            bid_price: bid.price,
            bid_quantity: bid.quantity
          }
      end

    entry
  end

  @doc false
  @spec entry_finder(integer(), atom(), list(Entry.t())) :: {atom(), Entry.t() | term()}
  def entry_finder(lvl, side, entries) do
    result =
      entries
      |> Enum.find(fn entry -> entry.price_level_index == lvl && entry.side == side end)

    {side, result}
  end

  @doc false
  @spec add_event(event(), State.t()) :: {{:ok}, State.t()}
  defp add_event(event, %{events: events_list} = state) do
    new_state = %{state | events: [event | events_list]}
    {{:ok}, new_state}
  end

  @doc false
  @spec update_level(event(), State.t()) :: {tuple(), State.t()}
  defp update_level(event, %{events: events_list} = state) do
    with nil <-
           Enum.find(events_list, fn entry ->
             entry.side == event.side && entry.price_level_index == event.price_level_index &&
               entry.price_level_index != 0
           end) do
      {{:error, reason: "Price level: #{event.price_level_index} does not exist"}, state}
    else
      val ->
        new_events = [event | List.delete(events_list, val)]

        {{:ok}, %{state | events: new_events}}
    end
  end

  @doc false
  @spec delete_level(Entry.t(), State.t()) :: {tuple(), State.t()}
  def delete_level(%{price_level_index: level}, %{events: events_list} = state) do
    events =
      Enum.filter(events_list, fn e ->
        e.price_level_index != level
      end)
      |> Enum.sort(fn a, b -> a.price_level_index < b.price_level_index end)
      |> Enum.reverse()

    %{price_level_index: top} = hd(events)

    dropped_events =
      events
      |> Enum.map(fn %{price_level_index: lvl} = entry ->
        if Enum.member?(level..top, lvl) do
          %{entry | price_level_index: lvl - 1}
        else
          entry
        end
      end)

    new_state = %{state | events: dropped_events}

    {{:ok}, new_state}
  end
end
