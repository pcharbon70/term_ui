defmodule TermUI.Test.Factories do
  @moduledoc """
  Test data factories for common test scenarios.

  Provides helper functions to generate test data consistently
  across test files.
  """

  alias TermUI.Layout.Constraint
  alias TermUI.Widgets.Table.Column

  @doc """
  Generates sample table data with id and name fields.

  ## Examples

      data = sample_table_data()        # 100 rows
      data = sample_table_data(1000)    # 1000 rows
  """
  @spec sample_table_data(pos_integer()) :: [map()]
  def sample_table_data(count \\ 100) do
    for i <- 1..count, do: %{id: i, name: "Item #{i}"}
  end

  @doc """
  Returns default table columns for testing.
  """
  @spec default_table_columns() :: [Column.t()]
  def default_table_columns do
    [
      Column.new(:id, "ID", width: Constraint.length(10)),
      Column.new(:name, "Name", width: Constraint.length(30))
    ]
  end

  @doc """
  Generates sample chart data.

  ## Examples

      data = sample_chart_data()
      # => [%{label: "A", value: 10}, %{label: "B", value: 25}, ...]
  """
  @spec sample_chart_data() :: [map()]
  def sample_chart_data do
    [
      %{label: "A", value: 10},
      %{label: "B", value: 25},
      %{label: "C", value: 15}
    ]
  end

  @doc """
  Generates sample sparkline values.
  """
  @spec sample_sparkline_values() :: [number()]
  def sample_sparkline_values do
    [5, 10, 3, 8, 15, 7, 12]
  end

  @doc """
  Returns sample tab definitions.
  """
  @spec sample_tabs() :: [map()]
  def sample_tabs do
    [
      %{id: :tab1, label: "Tab 1"},
      %{id: :tab2, label: "Tab 2"},
      %{id: :tab3, label: "Tab 3"}
    ]
  end

  @doc """
  Returns sample dialog buttons.
  """
  @spec sample_dialog_buttons() :: [map()]
  def sample_dialog_buttons do
    [
      %{id: :ok, label: "OK"},
      %{id: :cancel, label: "Cancel"}
    ]
  end
end
