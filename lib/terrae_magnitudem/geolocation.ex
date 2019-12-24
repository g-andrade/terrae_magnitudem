defmodule TerraeMagnitudem.GeoLocation do
  require Logger
  use GenServer

  ## ------------------------------------------------------------------
  ## Attribute Definitions
  ## ------------------------------------------------------------------

  @database_id __MODULE__
  @database_url "https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def child_specs() do
    [:locus.loader_child_spec(@database_id, @database_url),
      __MODULE__.child_spec(:_)]
  end

  def start_link(:_) do
    GenServer.start_link(__MODULE__, [])
  end

  def lookup(ip_address) do
    case :locus.lookup(@database_id, ip_address) do
      {:ok, %{"location" => %{"latitude" => latitude, "longitude" => longitude}}} ->
        {:ok, {latitude, longitude}}
      {:ok, %{}} ->
        {:error, :missing_coordinates}
      {:error, reason} ->
        {:error, reason}
    end
  end

  ## ------------------------------------------------------------------
  ## GenServer Function Definitions
  ## ------------------------------------------------------------------

  def init([]) do
    Logger.info("Waiting for database to load...")
    case :locus.wait_for_loader(@database_id, :infinity) do
      {:ok, version} ->
        Logger.info("Database version #{inspect version} has been loaded")
        :ignore
      {:error, reason} ->
        {:stop, {:database_failed_to_load, reason}}
    end
  end
end
