defmodule TermUI.Terminal.TtyNif do
  @moduledoc false

  @on_load :load_nif

  @dialyzer {:nowarn_function, [loaded?: 0, disable_control_flags: 0, restore_control_flags: 1]}

  @type control_flags :: {non_neg_integer(), non_neg_integer()}
  @type error_reason :: :nif_not_loaded | {:posix | :win32, non_neg_integer()}

  @doc false
  @spec load_nif() :: :ok
  def load_nif do
    with directory when is_list(directory) <- :code.priv_dir(:term_ui),
         path <- :filename.join(directory, ~c"term_ui_tty_nif") do
      case :erlang.load_nif(path, 0) do
        :ok -> :ok
        {:error, {operation, _detail}} when operation in [:reload, :upgrade] -> :ok
        {:error, _reason} -> :ok
      end
    else
      _error -> :ok
    end
  end

  @doc false
  @spec loaded?() :: boolean()
  def loaded?, do: false

  @doc false
  @spec disable_control_flags() :: {:ok, control_flags()} | {:error, error_reason()}
  def disable_control_flags, do: {:error, :nif_not_loaded}

  @doc false
  @spec restore_control_flags(control_flags()) :: :ok | {:error, error_reason()}
  def restore_control_flags(_flags), do: {:error, :nif_not_loaded}
end
