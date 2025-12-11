**. Elixir wrapper module**

Create lib/jido_code/console_mode.ex:

defmodule JidoCode.ConsoleMode do

@moduledoc """

Thin NIF wrapper around Windows \`GetConsoleMode\` / \`SetConsoleMode\`.

This module is \*\*Windows-only\*\*. On non-Windows platforms it will return

\`{:error, :not_implemented}\`.

"""

@on_load :load_nif

@doc false

def load_nif do

priv_dir = :code.priv_dir(:jido_code)

path = :filename.join(priv_dir, 'console_mode_nif')

case :erlang.load_nif(path, 0) do

:ok -> :ok

{:error, \_} = err -> err

end

end

@type handle :: :stdin | :stdout

\# Low-level NIFs (implemented in C)

defp get_mode_nif(\_handle), do: :erlang.nif_error(:nif_not_loaded)

defp set_mode_nif(\_handle, \_mode), do: :erlang.nif_error(:nif_not_loaded)

@doc """

Get the console mode for \`:stdin\` or \`:stdout\`.

Returns \`{:ok, mode :: non_neg_integer}\` or \`{:error, reason}\`.

"""

@spec get_mode(handle) :: {:ok, non_neg_integer} | {:error, term}

def get_mode(handle) when handle in \[:stdin, :stdout\],

do: get_mode_nif(handle)

@doc """

Set the console mode for \`:stdin\` or \`:stdout\`.

\`mode\` is a bitmask of Win32 console flags.

Returns \`:ok\` or \`{:error, reason}\`.

"""

@spec set_mode(handle, non_neg_integer) :: :ok | {:error, term}

def set_mode(handle, mode) when handle in \[:stdin, :stdout\] and is_integer(mode),

do: set_mode_nif(handle, mode)

\# --- Optional convenience: flags & raw-mode helper -----------------------

\# Input flags (subset of Win32 constants)

@enable_processed_input 0x0001

@enable_line_input 0x0002

@enable_echo_input 0x0004

@enable_window_input 0x0008

@enable_mouse_input 0x0010

@enable_virtual_terminal_input 0x0200

@doc """

Returns a map of named Windows input flags to their integer values.

"""

@spec input_flags() :: map()

def input_flags do

%{

enable_processed_input: @enable_processed_input,

enable_line_input: @enable_line_input,

enable_echo_input: @enable_echo_input,

enable_window_input: @enable_window_input,

enable_mouse_input: @enable_mouse_input,

enable_virtual_terminal_input: @enable_virtual_terminal_input

}

end

@doc """

Puts stdin into a "raw-ish" mode and returns the original mode.

\* Disables processed, line, and echo input.

\* Enables mouse + window + VT input.

Use the returned mode to restore:

orig = JidoCode.ConsoleMode.raw_input!()

\# ... run TUI ...

:ok = JidoCode.ConsoleMode.set_mode(:stdin, orig)

"""

@spec raw_input!() :: non_neg_integer | no_return

def raw_input! do

with {:ok, original} <- get_mode(:stdin) do

flags = input_flags()

disable_mask =

flags.enable_processed_input ||

flags.enable_line_input ||

flags.enable_echo_input

enable_mask =

flags.enable_mouse_input ||

flags.enable_window_input ||

flags.enable_virtual_terminal_input

raw_mode =

(original &&& bnot(disable_mask))

||| enable_mask

case set_mode(:stdin, raw_mode) do

:ok -> original

{:error, reason} -> raise "set_mode(:stdin, raw) failed: #{inspect(reason)}"

end

else

{:error, reason} ->

raise "get_mode(:stdin) failed: #{inspect(reason)}"

end

end

end

Note: we use console_mode_nif as the native library name. On Windows this will be console_mode_nif.dll in priv/.

**2\. C NIF implementation (Windows-only)**

Create c_src/console_mode_nif.c:

# include "erl_nif.h"

# ifdef \_WIN32

# include &lt;windows.h&gt;

# endif

static ERL_NIF_TERM atom_ok;

static ERL_NIF_TERM atom_error;

static ERL_NIF_TERM atom_not_implemented;

static ERL_NIF_TERM atom_invalid_handle;

// Helper to build {:error, reason}

static ERL_NIF_TERM make_error(ErlNifEnv\* env, ERL_NIF_TERM reason) {

return enif_make_tuple2(env, atom_error, reason);

}

# ifdef \_WIN32

// Convert :stdin / :stdout atom to Windows HANDLE

static int get_handle(ErlNifEnv\* env, ERL_NIF_TERM term, HANDLE\* handle) {

char buf\[16\];

if (!enif_get_atom(env, term, buf, sizeof(buf), ERL_NIF_LATIN1)) {

return 0;

}

if (strcmp(buf, "stdin") == 0) {

\*handle = GetStdHandle(STD_INPUT_HANDLE);

return 1;

} else if (strcmp(buf, "stdout") == 0) {

\*handle = GetStdHandle(STD_OUTPUT_HANDLE);

return 1;

}

return 0;

}

static ERL_NIF_TERM get_mode_nif(ErlNifEnv\* env, int argc, const ERL_NIF_TERM argv\[\]) {

HANDLE h;

DWORD mode;

if (argc != 1) {

return enif_make_badarg(env);

}

if (!get_handle(env, argv\[0\], &h) || h == INVALID_HANDLE_VALUE) {

return make_error(env, atom_invalid_handle);

}

if (!GetConsoleMode(h, &mode)) {

DWORD err = GetLastError();

ERL_NIF_TERM err_term = enif_make_uint(env, (unsigned int)err);

return make_error(env, err_term);

}

return enif_make_tuple2(env, atom_ok, enif_make_uint(env, (unsigned int)mode));

}

static ERL_NIF_TERM set_mode_nif(ErlNifEnv\* env, int argc, const ERL_NIF_TERM argv\[\]) {

HANDLE h;

unsigned int mode;

if (argc != 2) {

return enif_make_badarg(env);

}

if (!get_handle(env, argv\[0\], &h) || h == INVALID_HANDLE_VALUE) {

return make_error(env, atom_invalid_handle);

}

if (!enif_get_uint(env, argv\[1\], &mode)) {

return enif_make_badarg(env);

}

if (!SetConsoleMode(h, (DWORD)mode)) {

DWORD err = GetLastError();

ERL_NIF_TERM err_term = enif_make_uint(env, (unsigned int)err);

return make_error(env, err_term);

}

return atom_ok;

}

# else // !\_WIN32

// Non-Windows stubs

static ERL_NIF_TERM get_mode_nif(ErlNifEnv\* env, int argc, const ERL_NIF_TERM argv\[\]) {

(void)argc; (void)argv;

return make_error(env, atom_not_implemented);

}

static ERL_NIF_TERM set_mode_nif(ErlNifEnv\* env, int argc, const ERL_NIF_TERM argv\[\]) {

(void)argc; (void)argv;

return make_error(env, atom_not_implemented);

}

# endif

static int load(ErlNifEnv\* env, void\*\* priv, ERL_NIF_TERM info) {

(void)priv; (void)info;

atom_ok = enif_make_atom(env, "ok");

atom_error = enif_make_atom(env, "error");

atom_not_implemented= enif_make_atom(env, "not_implemented");

atom_invalid_handle = enif_make_atom(env, "invalid_handle");

return 0;

}

static int reload(ErlNifEnv\* env, void\*\* priv, ERL_NIF_TERM info) {

(void)env; (void)priv; (void)info;

return 0;

}

static int upgrade(ErlNifEnv\* env, void\*\* priv, void\*\* old_priv, ERL_NIF_TERM info) {

(void)env; (void)priv; (void)old_priv; (void)info;

return 0;

}

static void unload(ErlNifEnv\* env, void\* priv) {

(void)env; (void)priv;

}

static ErlNifFunc nif_funcs\[\] = {

{"get_mode_nif", 1, get_mode_nif},

{"set_mode_nif", 2, set_mode_nif}

};

// Module name must match Elixir module: Elixir.JidoCode.ConsoleMode

ERL_NIF_INIT(Elixir.JidoCode.ConsoleMode, nif_funcs, &load, &reload, &upgrade, &unload);

Key points:

- On Windows, it actually calls GetConsoleMode / SetConsoleMode.
- On non-Windows, it just returns {:error, :not_implemented} so the module doesn't explode if required accidentally.
- Handles :stdin / :stdout atoms and maps them to GetStdHandle.

**3\. Basic build setup (Mix + elixir_make)**

One simple way (if you're not already using something else) is :elixir_make.

In mix.exs:

defp deps do

\[

{:elixir_make, "~> 0.9", runtime: false}

\]

end

def project do

\[

app: :jido_code,

version: "0.1.0",

elixir: "~> 1.17",

compilers: \[:elixir_make\] ++ Mix.compilers(),

make_clean: \["clean"\],

\# ...

\]

end

Then Makefile in project root:

PRIV_DIR = priv

NIF_NAME = console_mode_nif

all: \$(PRIV_DIR)/\$(NIF_NAME).dll

\$(PRIV_DIR)/\$(NIF_NAME).dll: c_src/console_mode_nif.c

mkdir -p \$(PRIV_DIR)

cl /LD /Fe\$@ c_src/console_mode_nif.c /I"%ERTS_INCLUDE_DIR%"

clean:

\$(RM) \$(PRIV_DIR)/\$(NIF_NAME).dll

On Windows with MSVC you'll need ERTS_INCLUDE_DIR set (Elixir/Erlang install usually provides it; or you can hardcode the path). If you prefer MinGW or something else, swap cl for gcc and adjust flags.

(You clearly know your way around build tooling, so feel free to slot this into your existing native build story instead.)

**4\. Example usage from IEx**

Once compiled:

iex> JidoCode.ConsoleMode.get_mode(:stdin)

{:ok, 119}

iex> flags = JidoCode.ConsoleMode.input_flags()

%{

enable_echo_input: 4,

enable_line_input: 2,

enable_mouse_input: 16,

enable_processed_input: 1,

enable_virtual_terminal_input: 512,

enable_window_input: 8

}

iex> orig = JidoCode.ConsoleMode.raw_input!()

119

\# …run your TUI…

iex> :ok = JidoCode.ConsoleMode.set_mode(:stdin, orig)

:ok

You can now:

- Toggle raw-ish mode on Windows.
- Use that in TAU / your TUI to get proper key + mouse handling instead of just echoed escape sequences.
