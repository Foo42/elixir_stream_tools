defmodule StreamWeaver.Mixfile do
  use Mix.Project

  def project do
    [app: :stream_weaver,
     version: "0.0.1",
     elixir: "~> 1.0",
     name: "StreamWeaver",
     maintainers: ["julianhaeger@gmail.com"],
     links: ["https://github.com/Foo42/elixir_stream_tools"],
     description: "Library for working with streams",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    []
  end
end
