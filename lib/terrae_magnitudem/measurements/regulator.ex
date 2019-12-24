defmodule TerraeMagnitudem.Measurements.Regulator do
  @behaviour :sregulator

  ## ------------------------------------------------------------------
  ## Attribute Definitions
  ## ------------------------------------------------------------------

  @server __MODULE__

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def child_spec() do
    start_args = [{:local, @server}, __MODULE__, [], []]
    %{id: __MODULE__,
      start: {:sregulator, :start_link, start_args}
    }
  end

  def async_ask() do
    :sregulator.async_ask(@server)
  end

  def done(pid, ref) do
    :sregulator.done(pid, ref)
  end

  ## ------------------------------------------------------------------
  ## sregulator Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def init([]) do
	queue_spec = queue_spec()
    valve_spec = valve_spec()
    meter_specs = [overload_meter_spec()]
    {:ok, {queue_spec, valve_spec, meter_specs}}
  end

  ## ------------------------------------------------------------------
  ## Private Function Definitions
  ## ------------------------------------------------------------------

  defp queue_spec() do
    {:sbroker_drop_queue, %{max: 500}}
  end

  defp valve_spec() do
    {:sregulator_rate_valve,
      %{limit: 1,
        interval: 200
      }}
  end

  defp overload_meter_spec() do
    {:sbroker_overload_meter, %{alarm: {:overload, @server}}}
  end
end
