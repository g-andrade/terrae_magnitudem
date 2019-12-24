defmodule TerraeMagnitudem.HttpHandlers.StaticFiles do
  ## ------------------------------------------------------------------
  ## API Function Definitions
  ## ------------------------------------------------------------------

  def routes() do
    [
      {'/', :cowboy_static, {:priv_file, :terrae_magnitudem, 'static/index.html'}},
      {'/[...]', :cowboy_static, {:priv_dir, :terrae_magnitudem, 'static'}}
    ]
  end
end
