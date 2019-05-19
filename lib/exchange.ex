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
  This function boots up our stock exhange and gets it ready to handle events 

  ## Parameters 
  opts: A keyword list of start options, at the moment these options are ignored 
  """
  @spec start_link(list()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @doc """
  This client function handles received events for the stock exchange it performs 
  the relevant action according to the event's instruction 

  ## Parameters 
  * `exchange` - the pid for a running exchange
  * `event` - event for the exchange to process 

  ## Examples 
  """
  @spec send_instruction(pid(), event()) :: handle_event_response()
  def send_instruction(pid, event) do
    entry = struct(Entry, event)
    GenServer.call(pid, {:handle_event, entry})
  end

  @doc """
  Initialized the GenServer with a blank state and ready's the event handling
  """
  @spec init(map()) :: {:ok, State.t()}
  def init(_args) do
    {:ok, %State{}}
  end

  @doc """
  Callback to process incoming events into to the exchange

  ## Parameters
  * instruction -  atom indicating the instruction to the server 
  * pid - process identifier of sender
  * state - current server state 
  """
  @spec handle_call(tuple(), pid(), State.t()) :: handle_event_response()
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
