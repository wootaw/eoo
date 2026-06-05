defmodule Eoo.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Elixir 电子表格解析库 — 支持 XLSX、ODS、CSV"

  def project do
    [
      app: :eoo,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: @description,
      source_url: "https://github.com/roo-rb/eoo",
      homepage_url: "https://github.com/roo-rb/eoo",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :xmerl, :crypto]
    ]
  end

  defp deps do
    [
      # 零外部依赖 — 使用 Erlang/OTP 内置模块 (:xmerl, :zip, :crypto)
    ]
  end

  defp package do
    [
      name: :eoo,
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/roo-rb/eoo",
        "Original Roo (Ruby)" => "https://github.com/roo-rb/roo"
      }
    ]
  end

  defp docs do
    [
      main: "Eoo",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
