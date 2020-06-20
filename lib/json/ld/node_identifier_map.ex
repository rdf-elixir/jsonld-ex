defmodule JSON.LD.NodeIdentifierMap do
  @moduledoc nil

  use GenServer

  # Client API

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec stop(GenServer.server(), atom, timeout) :: :ok
  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    :ok = GenServer.stop(pid, reason, timeout)
  end

  @doc """
  Generate Blank Node Identifier

  Details at <https://www.w3.org/TR/json-ld-api/#generate-blank-node-identifier>
  """
  @spec generate_blank_node_id(GenServer.server(), String.t() | nil) :: String.t()
  def generate_blank_node_id(pid, identifier \\ nil) do
    GenServer.call(pid, {:generate_id, identifier})
  end

  # Server Callbacks

  @spec init(:ok) :: {:ok, map}
  def init(:ok) do
    {:ok, %{map: %{}, counter: 0}}
  end

  @spec handle_call({:generate_id, String.t() | nil}, GenServer.from(), map) ::
          {:reply, String.t(), map}
  def handle_call({:generate_id, identifier}, _, %{map: map, counter: counter} = state) do
    if identifier && map[identifier] do
      {:reply, map[identifier], state}
    else
      blank_node_id = "_:b#{counter}"
      map = if identifier, do: Map.put(map, identifier, blank_node_id), else: map

      {:reply, blank_node_id, %{counter: counter + 1, map: map}}
    end
  end
end
