defmodule TerraeMagnitudem.HttpHandlers.MeasurementStats do
  @behaviour :cowboy_rest

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def routes() do
    [{'/api/v1/measurement-stats', __MODULE__, :_}]
  end

  ## ------------------------------------------------------------------
  ## cowboy_rest Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def init(req, :_) do
    {:cowboy_rest, req, :no_state}
  end

  @impl true
  def allowed_methods(req, state) do
    value = ["HEAD", "GET", "OPTIONS"]
    {value, req, state}
  end

  @impl true
  def content_types_provided(req, state) do
    value = [{{"application", "json", :"*"}, :to_json}]
    {value, req, state}
  end

  def to_json(req, state) do
    stats = TerraeMagnitudem.Measurements.stats()
    response_body = Jason.encode_to_iodata!(stats)
    {response_body, req, state}
  end
end
