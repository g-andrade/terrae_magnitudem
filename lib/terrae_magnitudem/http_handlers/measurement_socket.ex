defmodule TerraeMagnitudem.HttpHandlers.MeasurementSocket do
  require Logger
  require Record
  use Bitwise
  @behaviour :cowboy_websocket

  ## ------------------------------------------------------------------
  ## Record Definitions
  ## ------------------------------------------------------------------

  Record.defrecordp(:state,
    session_id: nil,
    peer_location: nil,
    peer_angle: nil,
    measurements_bucket: nil,
    regulator_ask_ref: nil,
    regulator_pid: nil,
    regulator_work_ref: nil,
    unreplied_ping_id: nil,
    unreplied_ping_ts: nil
  )

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def routes() do
    [{'/api/v1/measurement-socket', __MODULE__, :_}]
  end

  ## ------------------------------------------------------------------
  ## cowboy_websocket Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def init(req, :_) do
    ip_address = peer_ip_address(req)
    case TerraeMagnitudem.GeoLocation.lookup(ip_address) do
    #case TerraeMagnitudem.GeoLocation.lookup("85.244.253.226") do
      {:ok, location} ->
        websocket_init_params = %{peer_ip_address: ip_address, peer_location: location}
        websocket_opts = %{idle_timeout: 180_000}
        {:cowboy_websocket, req, websocket_init_params, websocket_opts}
      {:error, reason} ->
        Logger.warn("[#{:inet.ntoa(ip_address)}] Failed to geolocate: #{inspect reason}")
        req = :cowboy_req.reply(400, req)
        {:ok, req, :_}
    end
  end

  @impl true
  def websocket_init(params) do
    %{peer_ip_address: ip_address, peer_location: location} = params
    session_id = :inet.ntoa(ip_address)
    Logger.info("#{session_id} New session")
    angle = TerraeMagnitudem.Measurements.angle_between_us_and_peer(location)
    measurements_bucket = TerraeMagnitudem.Measurements.bucket_for_peer(ip_address)

    await = TerraeMagnitudem.Measurements.Regulator.async_ask()
    {:await, regulator_ask_ref, regulator_pid} = await
    state = state(
      session_id: session_id,
      peer_location: location,
      peer_angle: angle,
      measurements_bucket: measurements_bucket,
      regulator_ask_ref: regulator_ask_ref,
      regulator_pid: regulator_pid
    )
    {[], state}
  end

  @impl true
  def websocket_handle(:ping, state) do
    {[], state}
  end

  @impl true
  def websocket_handle({:pong, ping_id}, state(unreplied_ping_id: ping_id) = state) do
    state(
      regulator_pid: regulator_pid,
      regulator_work_ref: regulator_work_ref,
      unreplied_ping_ts: ping_ts
    ) = state

    rtt = System.monotonic_time() - ping_ts
    {:stop, _} = TerraeMagnitudem.Measurements.Regulator.done(regulator_pid, regulator_work_ref)
    report_measurement(rtt, state)

    await = TerraeMagnitudem.Measurements.Regulator.async_ask()
    {:await, regulator_ask_ref, new_regulator_pid} = await
    updated_state = state(state,
      regulator_ask_ref: regulator_ask_ref,
      regulator_pid: new_regulator_pid,
      regulator_work_ref: nil,
      unreplied_ping_id: nil,
      unreplied_ping_ts: nil
    )
    {[], updated_state}
  end

  @impl true
  def websocket_handle(unexpected_event, state) do
    state(session_id: session_id) = state
    Logger.warn("[#{session_id}] Disconnecting after receiving #{inspect unexpected_event}")
    {[:close], state}
  end

  @impl true
  def websocket_info({ref, result}, state)
  when ref === state(state, :regulator_ask_ref)
  do
    Process.demonitor(ref, [:flush])
    case result do
      {:go, work_ref, new_regulator_pid, _, _} ->
        ping_id = <<(:rand.uniform((1 <<< 32)) - 1) :: size(32)>>
        updated_state = state(state,
          regulator_ask_ref: nil,
          regulator_pid: new_regulator_pid,
          regulator_work_ref: work_ref,
          unreplied_ping_id: ping_id,
          unreplied_ping_ts: System.monotonic_time()
        )
        {[ping: ping_id], updated_state}
      {:drop, _} ->
        state(session_id: session_id) = state
        Logger.warn("[#{session_id}] Disconnecting after regulator denied us")
        updated_state = state(state, regulator_ask_ref: nil, regulator_pid: nil)
        {[:close], updated_state}
    end
  end

  @impl true
  def websocket_info({:DOWN, ref, _, _, _}, state)
  when ref === state(state, :regulator_ask_ref)
  do
    state(session_id: session_id) = state
    Logger.warn("[#{session_id}] Disconnecting after regulator stopped")
    updated_state = state(state, regulator_ask_ref: nil, regulator_pid: nil)
    {[:close], updated_state}
  end

  @impl true
  def terminate(_reason, _req, :_) do
    :ok
  end

  @impl true
  def terminate(reason, _req, state(session_id: session_id)) do
    Logger.debug("[#{session_id}] Terminated (reason: #{inspect reason})")
  end

  ## ------------------------------------------------------------------
  ## Internal Function Definitions
  ## ------------------------------------------------------------------

  defp peer_ip_address(%{headers: %{"x-real-ip" => str_ip_address}}) do
    charlist_ip_address = String.to_charlist(str_ip_address)
    {:ok, ip_address} = :inet.parse_strict_address(charlist_ip_address)
    ip_address
  end

  defp peer_ip_address(req) do
    {ip_address, _port} = :cowboy_req.peer(req)
    ip_address
  end

  defp report_measurement(rtt, state) do
    state(measurements_bucket: bucket, peer_angle: angle) = state
    TerraeMagnitudem.Measurements.report_sample(bucket, angle, rtt)
  end
end
