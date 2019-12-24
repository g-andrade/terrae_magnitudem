defmodule TerraeMagnitudem.HttpListener do

  ## ------------------------------------------------------------------
  ## Attribute Definitions
  ## ------------------------------------------------------------------

  @port 8000 # TODO make this configurable

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def child_spec() do
    routes =
      TerraeMagnitudem.HttpHandlers.MeasurementSocket.routes()
      ++ TerraeMagnitudem.HttpHandlers.MeasurementStats.routes()
      ++ TerraeMagnitudem.HttpHandlers.StaticFiles.routes()

    dispatch = :cowboy_router.compile([_: routes])
    transport = :ranch_tcp
    transport_opts = [port: @port]
    protocol = :cowboy_clear
    protocol_opts = %{env: %{dispatch: dispatch}}
    :ranch.child_spec(__MODULE__, transport, transport_opts, protocol, protocol_opts)
  end
end
