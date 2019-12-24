defmodule TerraeMagnitudem.Application do
  @moduledoc false
  use Application

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def start(_type, _args) do
    children = List.flatten([
      TerraeMagnitudem.GeoLocation.child_specs(),
      TerraeMagnitudem.Measurements.child_spec([]),
      TerraeMagnitudem.Measurements.Regulator.child_spec(),
      TerraeMagnitudem.HttpListener.child_spec()
    ])
    opts = [strategy: :rest_for_one, name: TerraeMagnitudem.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
