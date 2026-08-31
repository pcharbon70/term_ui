defmodule TermUI.Integration.SSHRuntimeTest do
  use ExUnit.Case, async: false

  alias TermUI.Backend.SSH.Channel
  alias TermUI.{Command, Event, Frame}

  defmodule SSHApp do
    use TermUI.Elm

    @impl true
    def init(opts) do
      state = %{
        owner: Keyword.fetch!(opts, :test_owner),
        label: Keyword.fetch!(opts, :label),
        dimensions: Keyword.fetch!(opts, :dimensions),
        text: ""
      }

      send(state.owner, {:ssh_app_started, self(), state.label, state.dimensions})
      state
    end

    @impl true
    def event_to_msg(event, _state), do: {:msg, {:event, event}}

    @impl true
    def update({:event, %Event.Text{text: "q"}}, state) do
      {state, [Command.shutdown(:normal)]}
    end

    def update({:event, %Event.Text{text: text}}, state) do
      state = %{state | text: state.text <> text}
      send(state.owner, {:ssh_app_event, self(), state.label, {:text, state.text}})
      state
    end

    def update({:event, %Event.Resize{width: width, height: height}}, state) do
      state = %{state | dimensions: {width, height}}
      send(state.owner, {:ssh_app_event, self(), state.label, {:resize, width, height}})
      state
    end

    def update({:event, _event}, state), do: state

    @impl true
    def view(state) do
      {width, height} = state.dimensions
      Frame.from_rows([state.label, state.text], width, height)
    end

    @impl true
    def terminate(reason, state) do
      send(state.owner, {:ssh_app_stopped, self(), state.label, reason})
      :ok
    end
  end

  setup_all do
    assert {:ok, _applications} = Application.ensure_all_started(:ssh)
    directory = temporary_key_directory()
    write_host_key(directory)

    on_exit(fn -> File.rm_rf!(directory) end)
    {:ok, system_dir: directory}
  end

  test "an OTP SSH client starts, resizes, uses, and stops one TermUI session", context do
    {daemon, port} = start_daemon(context.system_dir, "one", self())
    connection = connect(port)
    channel = open_shell(connection, 40, 10)

    assert_receive {:ssh_app_started, runtime, "one", {40, 10}}, 2_000
    assert receive_channel_data(connection, channel, "one") =~ "one"

    assert :ok = :ssh_connection.send(connection, channel, "é")
    assert_receive {:ssh_app_event, ^runtime, "one", {:text, "é"}}, 2_000

    assert :ok = :ssh_connection.window_change(connection, channel, 60, 15)
    assert_receive {:ssh_app_event, ^runtime, "one", {:resize, 60, 15}}, 2_000

    assert :ok = :ssh_connection.send(connection, channel, "q")
    assert_receive {:ssh_app_stopped, ^runtime, "one", :normal}, 2_000
    assert_receive {:ssh_cm, ^connection, {:closed, ^channel}}, 2_000

    close_connection(connection)
    assert :ok = :ssh.stop_daemon(daemon)
  end

  test "two OTP SSH channels isolate state and disconnect failure", context do
    {daemon, port} = start_daemon(context.system_dir, "shared", self())
    connection = connect(port)
    channel_a = open_shell(connection, 30, 8)
    channel_b = open_shell(connection, 50, 12)

    assert_receive {:ssh_app_started, runtime_a, "shared", {30, 8}}, 2_000
    assert_receive {:ssh_app_started, runtime_b, "shared", {50, 12}}, 2_000
    refute runtime_a == runtime_b

    assert :ok = :ssh_connection.send(connection, channel_a, "a")
    assert_receive {:ssh_app_event, ^runtime_a, "shared", {:text, "a"}}, 2_000
    refute_receive {:ssh_app_event, ^runtime_b, "shared", {:text, _text}}, 100

    assert :ok = :ssh_connection.close(connection, channel_a)
    assert_receive {:ssh_app_stopped, ^runtime_a, "shared", _reason}, 2_000
    assert Process.alive?(runtime_b)

    assert :ok = :ssh_connection.send(connection, channel_b, "b")
    assert_receive {:ssh_app_event, ^runtime_b, "shared", {:text, "b"}}, 2_000

    close_connection(connection)
    assert_receive {:ssh_app_stopped, ^runtime_b, "shared", _reason}, 2_000
    assert :ok = :ssh.stop_daemon(daemon)
  end

  defp start_daemon(system_dir, label, owner) do
    password_fun = fn user, password -> user == ~c"termui" and password == ~c"secret" end

    options = [
      system_dir: String.to_charlist(system_dir),
      auth_methods: ~c"password",
      pwdfun: password_fun,
      ssh_cli:
        {Channel,
         [
           SSHApp,
           [runtime_options: [test_owner: owner, label: label], output_timeout: 2_000]
         ]}
    ]

    assert {:ok, daemon} = :ssh.daemon(:loopback, 0, options)
    assert {:port, port} = :ssh.daemon_info(daemon, :port)
    {daemon, port}
  end

  defp connect(port) do
    options = [
      user: ~c"termui",
      password: ~c"secret",
      user_interaction: false,
      silently_accept_hosts: true
    ]

    assert {:ok, connection} = :ssh.connect(~c"localhost", port, options, 5_000)
    connection
  end

  defp open_shell(connection, width, height) do
    assert {:ok, channel} = :ssh_connection.session_channel(connection, 5_000)

    assert :success =
             :ssh_connection.ptty_alloc(
               connection,
               channel,
               [term: ~c"xterm-256color", width: width, height: height, pty_opts: []],
               5_000
             )

    assert :ok = :ssh_connection.shell(connection, channel)
    channel
  end

  defp receive_channel_data(connection, channel, expected, output \\ "") do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, 0, data}} ->
        output = output <> data

        if String.contains?(output, expected) do
          output
        else
          receive_channel_data(connection, channel, expected, output)
        end
    after
      2_000 -> flunk("did not receive SSH channel output containing #{inspect(expected)}")
    end
  end

  defp close_connection(connection) do
    :ok = :ssh.close(connection)
  catch
    :exit, _reason -> :ok
  end

  defp temporary_key_directory do
    directory =
      Path.join(
        System.tmp_dir!(),
        "term-ui-ssh-#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(directory)
    directory
  end

  defp write_host_key(directory) do
    key = :public_key.generate_key({:rsa, 2_048, 65_537})
    entry = :public_key.pem_entry_encode(:RSAPrivateKey, key)
    path = Path.join(directory, "ssh_host_rsa_key")
    File.write!(path, :public_key.pem_encode([entry]))
    File.chmod!(path, 0o600)
  end
end
