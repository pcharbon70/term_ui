defmodule TermUI.Layout.Constraint do
  @moduledoc """
  Constraint types for the layout system.

  Constraints express how components request space from their parent container.
  They are declarative—describing desired outcome, not how to achieve it.

  ## Constraint Types

  - `length/1` - Exact size in terminal cells
  - `percentage/1` - Fraction of parent size (0-100)
  - `ratio/1` - Proportional share of remaining space
  - `min/1`, `max/1` - Bounds on size
  - `fill/0` - Take all remaining space

  ## Examples

      # Fixed 20 cells
      Constraint.length(20)

      # 50% of parent
      Constraint.percentage(50)

      # 50% but at least 10 cells
      Constraint.percentage(50) |> Constraint.with_min(10)

      # Fill remaining space
      Constraint.fill()

      # 2:1 ratio distribution
      [Constraint.ratio(2), Constraint.ratio(1)]

  ## Composition

  Constraints can be composed with bounds using `with_min/2` and `with_max/2`:

      Constraint.percentage(50) |> Constraint.with_min(10) |> Constraint.with_max(100)

  This creates a constraint that requests 50% of parent, but at least 10 and at most 100 cells.
  """

  require Logger

  # Constraint type structs

  defmodule Length do
    @moduledoc "Fixed size constraint in terminal cells."
    defstruct [:value]

    @type t :: %__MODULE__{value: non_neg_integer()}
  end

  defmodule Percentage do
    @moduledoc "Percentage of parent size constraint."
    defstruct [:value]

    @type t :: %__MODULE__{value: number()}
  end

  defmodule Ratio do
    @moduledoc "Proportional share of remaining space constraint."
    defstruct [:value]

    @type t :: %__MODULE__{value: number()}
  end

  defmodule Min do
    @moduledoc "Minimum size bound on another constraint."
    defstruct [:value, :constraint]

    @type t :: %__MODULE__{value: non_neg_integer(), constraint: TermUI.Layout.Constraint.t()}
  end

  defmodule Max do
    @moduledoc "Maximum size bound on another constraint."
    defstruct [:value, :constraint]

    @type t :: %__MODULE__{value: non_neg_integer(), constraint: TermUI.Layout.Constraint.t()}
  end

  defmodule Fill do
    @moduledoc "Fill remaining space constraint."
    defstruct []

    @type t :: %__MODULE__{}
  end

  @type t :: Length.t() | Percentage.t() | Ratio.t() | Min.t() | Max.t() | Fill.t()

  # Public API

  @doc """
  Creates a length constraint for exactly `n` cells.

  ## Parameters

  - `n` - Number of cells (non-negative integer)

  ## Returns

  A length constraint struct.

  ## Examples

      iex> Constraint.length(20)
      %TermUI.Layout.Constraint.Length{value: 20}

      iex> Constraint.length(0)
      %TermUI.Layout.Constraint.Length{value: 0}

  ## Errors

  Raises `ArgumentError` if `n` is negative or not an integer.
  """
  @spec length(non_neg_integer()) :: Length.t()
  def length(n) when is_integer(n) and n >= 0 do
    %Length{value: n}
  end

  def length(n) when is_integer(n) do
    raise ArgumentError, "length must be non-negative, got: #{n}"
  end

  def length(n) do
    raise ArgumentError, "length must be a non-negative integer, got: #{inspect(n)}"
  end

  @doc """
  Creates a percentage constraint for `p`% of parent size.

  ## Parameters

  - `p` - Percentage value (0 to 100, can be float)

  ## Returns

  A percentage constraint struct.

  ## Examples

      iex> Constraint.percentage(50)
      %TermUI.Layout.Constraint.Percentage{value: 50}

      iex> Constraint.percentage(33.33)
      %TermUI.Layout.Constraint.Percentage{value: 33.33}

  ## Errors

  Raises `ArgumentError` if `p` is outside 0-100 range.
  """
  @spec percentage(number()) :: Percentage.t()
  def percentage(p) when is_number(p) and p >= 0 and p <= 100 do
    %Percentage{value: p}
  end

  def percentage(p) when is_number(p) do
    raise ArgumentError, "percentage must be between 0 and 100, got: #{p}"
  end

  def percentage(p) do
    raise ArgumentError, "percentage must be a number between 0 and 100, got: #{inspect(p)}"
  end

  @doc """
  Creates a ratio constraint for proportional space distribution.

  Ratio constraints share remaining space (after fixed and percentage allocations)
  proportionally among siblings with ratio constraints.

  ## Parameters

  - `r` - Ratio value (positive number)

  ## Returns

  A ratio constraint struct.

  ## Examples

      # Two siblings with 2:1 ratio (first gets 2/3, second gets 1/3)
      [Constraint.ratio(2), Constraint.ratio(1)]

      # Three equal siblings
      [Constraint.ratio(1), Constraint.ratio(1), Constraint.ratio(1)]

  ## Errors

  Raises `ArgumentError` if `r` is not positive.
  """
  @spec ratio(number()) :: Ratio.t()
  def ratio(r) when is_number(r) and r > 0 do
    %Ratio{value: r}
  end

  def ratio(r) when is_number(r) do
    raise ArgumentError, "ratio must be positive, got: #{r}"
  end

  def ratio(r) do
    raise ArgumentError, "ratio must be a positive number, got: #{inspect(r)}"
  end

  @doc """
  Creates a minimum size constraint.

  When used alone, acts as a minimum size requirement.
  When composed with another constraint, acts as a lower bound.

  ## Parameters

  - `n` - Minimum size in cells (non-negative integer)

  ## Returns

  A min constraint struct with a fill constraint as default inner constraint.

  ## Examples

      # At least 10 cells
      Constraint.min(10)

  ## Errors

  Raises `ArgumentError` if `n` is negative or not an integer.
  """
  @spec min(non_neg_integer()) :: Min.t()
  def min(n) when is_integer(n) and n >= 0 do
    %Min{value: n, constraint: %Fill{}}
  end

  def min(n) when is_integer(n) do
    raise ArgumentError, "min must be non-negative, got: #{n}"
  end

  def min(n) do
    raise ArgumentError, "min must be a non-negative integer, got: #{inspect(n)}"
  end

  @doc """
  Creates a maximum size constraint.

  When used alone, acts as a maximum size requirement with fill behavior.
  When composed with another constraint, acts as an upper bound.

  ## Parameters

  - `n` - Maximum size in cells (non-negative integer)

  ## Returns

  A max constraint struct with a fill constraint as default inner constraint.

  ## Examples

      # At most 100 cells
      Constraint.max(100)

  ## Errors

  Raises `ArgumentError` if `n` is negative or not an integer.
  """
  @spec max(non_neg_integer()) :: Max.t()
  def max(n) when is_integer(n) and n >= 0 do
    %Max{value: n, constraint: %Fill{}}
  end

  def max(n) when is_integer(n) do
    raise ArgumentError, "max must be non-negative, got: #{n}"
  end

  def max(n) do
    raise ArgumentError, "max must be a non-negative integer, got: #{inspect(n)}"
  end

  @doc """
  Creates combined min/max bounds.

  ## Parameters

  - `min_val` - Minimum size in cells
  - `max_val` - Maximum size in cells

  ## Returns

  A min constraint wrapping a max constraint with fill behavior.

  ## Examples

      # Between 10 and 100 cells
      Constraint.min_max(10, 100)

  ## Errors

  Raises `ArgumentError` if min > max or values are invalid.
  """
  @spec min_max(non_neg_integer(), non_neg_integer()) :: Min.t()
  def min_max(min_val, max_val)
      when is_integer(min_val) and is_integer(max_val) and min_val >= 0 and max_val >= 0 do
    if min_val > max_val do
      raise ArgumentError, "min (#{min_val}) cannot be greater than max (#{max_val})"
    end

    %Min{value: min_val, constraint: %Max{value: max_val, constraint: %Fill{}}}
  end

  def min_max(min_val, max_val) do
    raise ArgumentError,
          "min_max requires non-negative integers, got: min=#{inspect(min_val)}, max=#{inspect(max_val)}"
  end

  @doc """
  Creates a fill constraint that takes all remaining space.

  Fill is equivalent to `ratio(1)` in calculation but semantically distinct—
  it means "take whatever is left" rather than "share proportionally".

  ## Returns

  A fill constraint struct.

  ## Examples

      # Main content area fills remaining space
      Constraint.fill()

  Multiple fills distribute space equally among them.
  """
  @spec fill() :: Fill.t()
  def fill do
    %Fill{}
  end

  @doc """
  Adds a minimum bound to a constraint.

  ## Parameters

  - `constraint` - The constraint to bound
  - `min_val` - Minimum size in cells

  ## Returns

  The constraint wrapped in a min bound.

  ## Examples

      # 50% but at least 10 cells
      Constraint.percentage(50) |> Constraint.with_min(10)
  """
  @spec with_min(t(), non_neg_integer()) :: Min.t()
  def with_min(constraint, min_val) when is_integer(min_val) and min_val >= 0 do
    %Min{value: min_val, constraint: constraint}
  end

  def with_min(_constraint, min_val) do
    raise ArgumentError, "with_min requires non-negative integer, got: #{inspect(min_val)}"
  end

  @doc """
  Adds a maximum bound to a constraint.

  ## Parameters

  - `constraint` - The constraint to bound
  - `max_val` - Maximum size in cells

  ## Returns

  The constraint wrapped in a max bound.

  ## Examples

      # 50% but at most 100 cells
      Constraint.percentage(50) |> Constraint.with_max(100)
  """
  @spec with_max(t(), non_neg_integer()) :: Max.t()
  def with_max(constraint, max_val) when is_integer(max_val) and max_val >= 0 do
    %Max{value: max_val, constraint: constraint}
  end

  def with_max(_constraint, max_val) do
    raise ArgumentError, "with_max requires non-negative integer, got: #{inspect(max_val)}"
  end

  @doc """
  Resolves a constraint to a concrete size given available space.

  This is used by the constraint solver to calculate final sizes.

  ## Parameters

  - `constraint` - The constraint to resolve
  - `available` - Available space in cells
  - `opts` - Options including `:remaining` for ratio calculations

  ## Returns

  The resolved size in cells (non-negative integer).

  ## Examples

      iex> Constraint.resolve(Constraint.length(20), 100)
      20

      iex> Constraint.resolve(Constraint.percentage(50), 100)
      50

      iex> Constraint.resolve(Constraint.fill(), 100, remaining: 30)
      30
  """
  @spec resolve(t(), non_neg_integer(), keyword()) :: non_neg_integer()
  def resolve(constraint, available, opts \\ [])

  def resolve(%Length{value: n}, available, _opts) do
    if n > available do
      Logger.warning("Length constraint #{n} exceeds available space #{available}, truncating")
      available
    else
      n
    end
  end

  def resolve(%Percentage{value: p}, available, _opts) do
    result = available * p / 100
    round(result)
  end

  def resolve(%Ratio{value: r}, _available, opts) do
    remaining = Keyword.get(opts, :remaining, 0)
    total_ratio = Keyword.get(opts, :total_ratio, r)

    if total_ratio == 0 do
      0
    else
      result = remaining * r / total_ratio
      round(result)
    end
  end

  def resolve(%Fill{}, _available, opts) do
    Keyword.get(opts, :remaining, 0)
  end

  def resolve(%Min{value: min_val, constraint: inner}, available, opts) do
    inner_size = resolve(inner, available, opts)
    max(min_val, inner_size)
  end

  def resolve(%Max{value: max_val, constraint: inner}, available, opts) do
    inner_size = resolve(inner, available, opts)
    min(max_val, inner_size)
  end

  @doc """
  Returns the constraint type as an atom.

  Useful for categorizing constraints during solving.

  ## Examples

      iex> Constraint.type(Constraint.length(20))
      :length

      iex> Constraint.type(Constraint.percentage(50))
      :percentage
  """
  @spec type(t()) :: atom()
  def type(%Length{}), do: :length
  def type(%Percentage{}), do: :percentage
  def type(%Ratio{}), do: :ratio
  def type(%Fill{}), do: :fill
  def type(%Min{constraint: inner}), do: {:min, type(inner)}
  def type(%Max{constraint: inner}), do: {:max, type(inner)}

  @doc """
  Checks if a constraint is fixed (length or bounded length).

  Fixed constraints are allocated first during solving.
  """
  @spec fixed?(t()) :: boolean()
  def fixed?(%Length{}), do: true
  def fixed?(%Min{constraint: %Length{}}), do: true
  def fixed?(%Max{constraint: %Length{}}), do: true
  def fixed?(_), do: false

  @doc """
  Checks if a constraint uses remaining space (ratio or fill).
  """
  @spec flexible?(t()) :: boolean()
  def flexible?(%Ratio{}), do: true
  def flexible?(%Fill{}), do: true
  def flexible?(%Min{constraint: inner}), do: flexible?(inner)
  def flexible?(%Max{constraint: inner}), do: flexible?(inner)
  def flexible?(_), do: false

  @doc """
  Gets the minimum value from a constraint, if bounded.
  """
  @spec get_min(t()) :: non_neg_integer() | nil
  def get_min(%Min{value: v}), do: v
  def get_min(_), do: nil

  @doc """
  Gets the maximum value from a constraint, if bounded.
  """
  @spec get_max(t()) :: non_neg_integer() | nil
  def get_max(%Max{value: v}), do: v
  def get_max(%Min{constraint: inner}), do: get_max(inner)
  def get_max(_), do: nil

  @doc """
  Gets the inner constraint, unwrapping bounds.
  """
  @spec unwrap(t()) :: t()
  def unwrap(%Min{constraint: inner}), do: unwrap(inner)
  def unwrap(%Max{constraint: inner}), do: unwrap(inner)
  def unwrap(constraint), do: constraint
end
