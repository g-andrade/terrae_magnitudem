defmodule TerraeMagnitudem.Measurements do
  use GenServer

  ## ------------------------------------------------------------------
  ## Attribute Definitions
  ## ------------------------------------------------------------------

  @server __MODULE__
  @samples_table TerraeMagnitudem.Measurements.Samples
  @number_of_buckets 1

  @stats_table TerraeMagnitudem.Measurements.Stats
  @stats_refresh_interval 1_000

  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @server)
  end

  def angle_between_us_and_peer(peer_location) do
    server_location = Application.get_env(:terrae_magnitudem, :server_location)
    {lat1, lon1} = location_to_radians(server_location)
    {lat2, lon2} = location_to_radians(peer_location)
    lat_diff = normalized_radians(lat2 - lat1)
    lon_diff = normalized_radians(lon2 - lon1)
    normalized_radians( :math.sqrt((lat_diff * lat_diff) + (lon_diff * lon_diff)) )
  end

  def bucket_for_peer(peer_ip_address) do
    :erlang.phash2(peer_ip_address, @number_of_buckets) + 1
  end

  def report_sample(bucket, angle, rtt) do
    # FIXME make the update atomic, otherwise we're going to lose samples
    [{_, prev_samples}] = :ets.lookup(@samples_table, bucket)
    rtt_in_seconds = rtt / System.convert_time_unit(1, :second, :native)
    angles_per_second = angle / rtt_in_seconds
    updated_samples =
      case prev_samples do
        _ when length(prev_samples) == 15 ->
          [angles_per_second | :lists.sublist(prev_samples, 9)]
        _ when length(prev_samples) < 15 ->
          [angles_per_second|prev_samples]
      end
    :ets.insert(@samples_table, {bucket, updated_samples})
  end

  def stats() do
    [stats: stats] = :ets.lookup(@stats_table, :stats)
    stats
  end

  ## ------------------------------------------------------------------
  ## GenServer Function Definitions
  ## ------------------------------------------------------------------

  @impl true
  def init([]) do
    _ = create_samples_table()
    _ = create_stats_table()
    create_buckets()
    _ = schedule_stats_refresh(0)
    {:ok, :no_state}
  end

  @impl true
  def handle_call(call, from, state) do
    {:stop, {:unexpected_call, call, from}, state}
  end

  @impl true
  def handle_cast(cast, state) do
    {:stop, {:unexpected_cast, cast}, state}
  end

  @impl true
  def handle_info(:refresh_stats, state) do
    refresh_stats()
    _ = schedule_stats_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    {:stop, {:unexpected_info, info}, state}
  end

  ## ------------------------------------------------------------------
  ## Internal Function Definitions - Initialization and Stats
  ## ------------------------------------------------------------------

  defp create_samples_table() do
    :ets.new(@samples_table, [:public, :named_table, write_concurrency: true])
  end

  defp create_stats_table() do
    :ets.new(@stats_table, [:protected, :named_table, read_concurrency: true])
  end

  defp create_buckets() do
    objects = for n <- 1..@number_of_buckets, do: {n, []}
    :ets.insert(@samples_table, objects)
  end

  defp schedule_stats_refresh() do
    schedule_stats_refresh(@stats_refresh_interval)
  end

  defp schedule_stats_refresh(delay) do
    Process.send_after(self(), :refresh_stats, delay)
  end

  defp refresh_stats() do
    case all_samples() do
      [] ->
        :ets.insert(@stats_table, [stats: %{}])
      samples ->
        sorted_samples = Enum.sort(samples)
        stats = %{
          "mean" => Statistics.mean(sorted_samples),
          "p10" => Statistics.percentile(sorted_samples, 10),
          "median" => Statistics.percentile(sorted_samples, 50),
          "p95" => Statistics.percentile(sorted_samples, 95),
          "p99" => Statistics.percentile(sorted_samples, 99)
        }
        :ets.insert(@stats_table, [stats: stats])
    end
  end

  defp all_samples() do
    :ets.foldl(
      fn ({_bucket, samples}, acc) ->
        samples ++ acc
      end,
      [], @samples_table)
  end

  ## ------------------------------------------------------------------
  ## Internal Function Definitions - Utuls
  ## ------------------------------------------------------------------

  defp location_to_radians({latitude, longitude})
  when latitude >= -90 and longitude <= +90 and longitude >= -180 and longitude <= +180
  do
    {degrees_to_radians(latitude), degrees_to_radians(longitude)}
  end

  def degrees_to_radians(degrees) do
    (degrees / 360.0) * 2.0 * :math.pi()
  end

  def normalized_radians(radians) do
    tau = 2 * :math.pi()
    cond do
      radians < 0 ->
        normalized_radians(radians + tau)
      radians <= tau ->
        radians
      radians > tau ->
        normalized_radians(radians - tau)
    end
  end
end
