defmodule JSON.LD.NodeIdentifierMap do
  @moduledoc nil

  use GenServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(pid, reason, timeout)
  end

  @doc """
  Generate Blank Node Identifier

  Details at <https://www.w3.org/TR/json-ld-api/#generate-blank-node-identifier>
  """
  def generate_blank_node_id(pid, identifier \\ nil) do
    GenServer.call(pid, {:generate_id, identifier})
  end


  # Server Callbacks

  def init(:ok) do
    {:ok, %{map: %{}, counter: 0}}
  end

  def handle_call({:generate_id, identifier}, _, %{map: map, counter: counter} = state) do
    if identifier && map[identifier] do
      {:reply, map[identifier], state}
    else
      blank_node_id = "_:b#{counter}"
      {:reply, blank_node_id, %{
          counter: counter + 1,
          map:
            if identifier do
              Map.put(map, identifier, blank_node_id)
            else
              map
            end
          }}
    end
  end

end
