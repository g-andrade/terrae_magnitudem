defmodule TerraeMagnitudem.MixProject do
  use Mix.Project

  def project do
    [
      app: :terrae_magnitudem,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TerraeMagnitudem.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.7"},
      #{:ex2ms, "~> 1.6"},
      {:jason, "~> 1.1.2"},
      {:locus, "~> 1.8"},
      {:recon, "~> 2.5"},
      {:sbroker, "~> 1.0"},
      {:statistics, "~> 0.6"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
