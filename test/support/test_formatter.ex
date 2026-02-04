# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

# Wrapper around ExUnit.CLIFormatter with trace output adjusted to avoid
# carriage-return overwrites on wrapped lines.
defmodule TermUI.TestFormatter do
  @moduledoc false
  use GenServer

  import ExUnit.Formatter,
    only: [format_times: 1, format_filters: 2, format_test_failure: 5, format_test_all_failure: 5]

  ## Callbacks

  def init(opts) do
    newline = newline_sequence()

    puts_line("Running ExUnit with seed: #{opts[:seed]}, max_cases: #{opts[:max_cases]}", newline)
    print_filters(opts, :exclude, newline)
    print_filters(opts, :include, newline)
    puts_line("", newline)

    config = %{
      trace: opts[:trace],
      colors: colors(opts),
      width: get_terminal_width(),
      slowest: opts[:slowest],
      slowest_modules: opts[:slowest_modules],
      test_counter: %{},
      test_timings: [],
      failure_counter: 0,
      skipped_counter: 0,
      excluded_counter: 0,
      invalid_counter: 0,
      newline: newline
    }

    {:ok, config}
  end

  def handle_cast({:suite_started, _opts}, config) do
    {:noreply, config}
  end

  def handle_cast({:suite_finished, times_us}, config) do
    test_type_counts = collect_test_type_counts(config)

    if test_type_counts == 0 and config.excluded_counter > 0 do
      puts_line(invalid("All tests have been excluded.", config), config.newline)
    end

    IO.write(config.newline)
    puts_line(format_times(times_us), config.newline)

    if config.slowest > 0 do
      puts_line(format_slowest_tests(config, times_us.run), config.newline)
    end

    if config.slowest_modules > 0 do
      puts_line(format_slowest_modules(config, times_us.run), config.newline)
    end

    print_summary(config, false)
    {:noreply, config}
  end

  def handle_cast({:test_started, %ExUnit.Test{}}, config) do
    # In trace mode, only print the finished line (with timing) to avoid
    # carriage-return overwrites when lines wrap.
    {:noreply, config}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: nil} = test}, config) do
    if config.trace do
      puts_line(success(trace_test_result(test), config), config.newline)
    else
      IO.write(success(".", config))
    end

    config = %{config | test_counter: update_test_counter(config.test_counter, test)}
    {:noreply, update_test_timings(config, test)}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: {:excluded, reason}} = test}, config)
      when is_binary(reason) do
    if config.trace, do: puts_line(trace_test_excluded(test), config.newline)

    test_counter = update_test_counter(config.test_counter, test)
    config = %{config | test_counter: test_counter, excluded_counter: config.excluded_counter + 1}

    {:noreply, config}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: {:skipped, reason}} = test}, config)
      when is_binary(reason) do
    if config.trace do
      puts_line(skipped(trace_test_skipped(test), config), config.newline)
    else
      IO.write(skipped("*", config))
    end

    test_counter = update_test_counter(config.test_counter, test)
    config = %{config | test_counter: test_counter, skipped_counter: config.skipped_counter + 1}

    {:noreply, config}
  end

  def handle_cast(
        {:test_finished,
         %ExUnit.Test{state: {:invalid, %ExUnit.TestModule{state: {:failed, _}}}} = test},
        config
      ) do
    if config.trace do
      puts_line(invalid(trace_test_result(test), config), config.newline)
    else
      IO.write(invalid("?", config))
    end

    test_counter = update_test_counter(config.test_counter, test)
    config = %{config | test_counter: test_counter, invalid_counter: config.invalid_counter + 1}

    {:noreply, config}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: {:failed, failures}} = test}, config) do
    if config.trace do
      puts_line(failure(trace_test_result(test), config), config.newline)
    end

    formatted =
      format_test_failure(
        test,
        failures,
        config.failure_counter + 1,
        config.width,
        &formatter(&1, &2, config)
      )

    print_failure(formatted, config)
    print_logs(test.logs)

    test_counter = update_test_counter(config.test_counter, test)
    failure_counter = config.failure_counter + 1
    config = %{config | test_counter: test_counter, failure_counter: failure_counter}

    {:noreply, update_test_timings(config, test)}
  end

  def handle_cast({:module_started, %ExUnit.TestModule{} = module}, config) do
    if config.trace do
      %{name: name, file: file, parameters: parameters} = module
      IO.write(config.newline)
      puts_line("#{inspect(name)} [#{Path.relative_to_cwd(file)}]", config.newline)

      if parameters != %{} do
        puts_line("Parameters: #{inspect(parameters)}", config.newline)
      end
    end

    {:noreply, config}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{state: nil}}, config) do
    {:noreply, config}
  end

  def handle_cast(
        {:module_finished, %ExUnit.TestModule{state: {:failed, failures}} = test_module},
        config
      ) do
    # The failed tests have already contributed to the counter,
    # so we should only add the successful tests to the count
    config =
      update_in(config.failure_counter, fn counter ->
        counter + Enum.count(test_module.tests, &is_nil(&1.state))
      end)

    formatted =
      format_test_all_failure(
        test_module,
        failures,
        config.failure_counter,
        config.width,
        &formatter(&1, &2, config)
      )

    print_failure(formatted, config)

    {:noreply, config}
  end

  def handle_cast(:max_failures_reached, config) do
    IO.write(failure("--max-failures reached, aborting test suite", config))
    {:noreply, config}
  end

  def handle_cast({:sigquit, current}, config) do
    IO.write([config.newline, config.newline])

    if current == [] do
      IO.write(
        failure(
          convert_newlines("Aborting test suite, showing results so far...\n\n", config),
          config
        )
      )
    else
      IO.write(
        failure(
          convert_newlines("Aborting test suite, the following have not completed:\n\n", config),
          config
        )
      )

      Enum.each(current, &puts_line(trace_aborted(&1), config.newline))

      IO.write(failure(convert_newlines("\nShowing results so far...\n\n", config), config))
    end

    print_summary(config, true)
    {:noreply, config}
  end

  def handle_cast(_, config) do
    {:noreply, config}
  end

  ## Tracing

  defp trace_test_time(%ExUnit.Test{time: time}) do
    "#{format_us(time)}ms"
  end

  defp trace_test_line(%ExUnit.Test{tags: tags}) do
    "L##{tags.line}"
  end

  defp trace_test_file_line(%ExUnit.Test{tags: tags}) do
    "#{Path.relative_to_cwd(tags.file)}:#{tags.line}"
  end

  defp trace_test_started(test) do
    String.replace("  * #{test.name}", "\n", " ")
  end

  defp trace_test_result(test) do
    "#{trace_test_started(test)} (#{trace_test_time(test)}) [#{trace_test_line(test)}]"
  end

  defp trace_test_excluded(test) do
    "#{trace_test_started(test)} (excluded) [#{trace_test_line(test)}]"
  end

  defp trace_test_skipped(test) do
    "#{trace_test_started(test)} (skipped) [#{trace_test_line(test)}]"
  end

  defp trace_aborted(%ExUnit.Test{} = test) do
    "* #{test.name} [#{trace_test_file_line(test)}]"
  end

  defp trace_aborted(%ExUnit.TestModule{name: name, file: file}) do
    "* #{inspect(name)} [#{Path.relative_to_cwd(file)}]"
  end

  defp normalize_us(us) do
    div(us, 1000)
  end

  defp format_us(us) do
    us = div(us, 10)

    if us < 10 do
      "0.0#{us}"
    else
      us = div(us, 10)
      "#{div(us, 10)}.#{rem(us, 10)}"
    end
  end

  defp update_test_counter(test_counter, %{state: {:excluded, _reason}}) do
    test_counter
  end

  defp update_test_counter(test_counter, %{tags: %{test_type: test_type}}) do
    Map.update(test_counter, test_type, 1, &(&1 + 1))
  end

  ## Slowest

  defp format_slowest_tests(%{slowest: slowest, test_timings: timings}, run_us) do
    slowest_tests =
      timings
      |> Enum.sort_by(fn %{time: time} -> -time end)
      |> Enum.take(slowest)

    slowest_us = Enum.reduce(slowest_tests, 0, &(&1.time + &2))
    slowest_time = slowest_us |> normalize_us() |> format_us()
    percentage = Float.round(slowest_us / run_us * 100, 1)

    [
      "\nTop #{slowest} slowest (#{slowest_time}s), #{percentage}% of total time:\n\n"
      | Enum.map(slowest_tests, &format_slow_test/1)
    ]
  end

  defp format_slowest_modules(%{slowest_modules: slowest, test_timings: timings}, run_us) do
    slowest_tests =
      timings
      |> Enum.group_by(
        fn %{module: module, tags: tags} ->
          {module, tags.file}
        end,
        fn %{time: time} -> time end
      )
      |> Enum.into([], fn {{module, trace_test_file_line}, timings} ->
        {module, trace_test_file_line, Enum.sum(timings)}
      end)
      |> Enum.sort_by(fn {_module, _, sum_timings} -> sum_timings end, :desc)
      |> Enum.take(slowest)

    slowest_us =
      Enum.reduce(slowest_tests, 0, fn {_module, _, sum_timings}, acc ->
        acc + sum_timings
      end)

    slowest_time = slowest_us |> normalize_us() |> format_us()
    percentage = Float.round(slowest_us / run_us * 100, 1)

    [
      "\nTop #{slowest} slowest (#{slowest_time}s), #{percentage}% of total time:\n\n"
      | Enum.map(slowest_tests, &format_slow_module/1)
    ]
  end

  defp format_slow_test(%ExUnit.Test{time: time, module: module} = test) do
    "#{trace_test_started(test)} (#{inspect(module)}) (#{format_us(time)}ms) " <>
      "[#{trace_test_file_line(test)}]\n"
  end

  defp format_slow_module({module, test_file_path, timings}) do
    "#{inspect(module)} (#{format_us(timings)}ms)\n [#{Path.relative_to_cwd(test_file_path)}]\n"
  end

  defp update_test_timings(
         %{slowest: slowest, slowest_modules: slowest_modules} = config,
         %ExUnit.Test{} = test
       ) do
    if slowest > 0 or slowest_modules > 0 do
      # Do not store logs, as they are not used for timings and consume memory.
      update_in(config.test_timings, &[%{test | logs: ""} | &1])
    else
      config
    end
  end

  ## Printing

  defp print_summary(config, force_failures?) do
    test_type_counts = collect_test_type_counts(config)
    test_counter = test_counter_or_default(config, test_type_counts)
    formatted_test_type_counts = format_test_type_counts(test_counter)
    failure_pl = pluralize(config.failure_counter, "failure", "failures")

    message =
      "#{formatted_test_type_counts}#{config.failure_counter} #{failure_pl}"
      |> if_true(
        config.invalid_counter > 0,
        &(&1 <> ", #{config.invalid_counter} invalid")
      )
      |> if_true(
        config.skipped_counter > 0,
        &(&1 <> ", " <> skipped("#{config.skipped_counter} skipped", config))
      )
      |> if_true(
        config.excluded_counter > 0,
        &(&1 <> " (#{config.excluded_counter} excluded)")
      )

    cond do
      config.failure_counter > 0 or force_failures? ->
        puts_line(failure(message, config), config.newline)

      config.invalid_counter > 0 ->
        puts_line(invalid(message, config), config.newline)

      test_type_counts > 0 && config.excluded_counter == test_type_counts ->
        puts_line(invalid(message, config), config.newline)

      true ->
        puts_line(success(message, config), config.newline)
    end
  end

  defp if_true(value, false, _fun), do: value
  defp if_true(value, true, fun), do: fun.(value)

  defp print_filters(opts, key, newline) do
    case opts[key] do
      [] -> :ok
      filters -> puts_line(format_filters(filters, key), newline)
    end
  end

  defp print_failure(formatted, config) do
    cond do
      config.trace -> puts_line("", config.newline)
      true -> IO.write([config.newline, config.newline])
    end

    puts_line(formatted, config.newline)
  end

  defp format_test_type_counts(test_counter) do
    test_counter
    |> Enum.sort()
    |> Enum.map(fn {test_type, count} ->
      type_pluralized = pluralize(count, test_type, ExUnit.plural_rule(test_type |> to_string()))

      "#{count} #{type_pluralized}, "
    end)
  end

  defp test_counter_or_default(_config, 0) do
    %{test: 0}
  end

  defp test_counter_or_default(%{test_counter: test_counter} = _config, _test_type_counts) do
    test_counter
  end

  defp collect_test_type_counts(%{test_counter: test_counter} = _config) do
    Enum.reduce(test_counter, 0, fn {_, count}, acc ->
      acc + count
    end)
  end

  # Color styles

  defp colorize(key, string, %{colors: colors}) do
    if escape = colors[:enabled] && colors[key] do
      [escape, string, :reset]
      |> IO.ANSI.format_fragment(true)
      |> IO.iodata_to_binary()
    else
      string
    end
  end

  defp colorize_doc(escape, doc, %{colors: colors}) do
    if colors[:enabled] do
      Inspect.Algebra.color_doc(doc, escape, %Inspect.Opts{syntax_colors: colors})
    else
      doc
    end
  end

  defp success(msg, config) do
    colorize(:success, msg, config)
  end

  defp invalid(msg, config) do
    colorize(:invalid, msg, config)
  end

  defp skipped(msg, config) do
    colorize(:skipped, msg, config)
  end

  defp failure(msg, config) do
    colorize(:failure, msg, config)
  end

  # Diff formatting

  defp formatter(:diff_enabled?, _, %{colors: colors}),
    do: colors[:enabled]

  defp formatter(:diff_delete, doc, config),
    do: colorize_doc(:diff_delete, doc, config)

  defp formatter(:diff_delete_whitespace, doc, config),
    do: colorize_doc(:diff_delete_whitespace, doc, config)

  defp formatter(:diff_insert, doc, config),
    do: colorize_doc(:diff_insert, doc, config)

  defp formatter(:diff_insert_whitespace, doc, config),
    do: colorize_doc(:diff_insert_whitespace, doc, config)

  defp formatter(:blame_diff, msg, %{colors: colors} = config) do
    if colors[:enabled] do
      colorize(:diff_delete, msg, config)
    else
      "-" <> msg <> "-"
    end
  end

  defp formatter(key, msg, config), do: colorize(key, msg, config)

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_, _singular, plural), do: plural

  defp get_terminal_width do
    case :io.columns() do
      {:ok, width} -> max(40, width)
      _ -> 80
    end
  end

  @default_colors [
    diff_delete: :red,
    diff_delete_whitespace: IO.ANSI.color_background(2, 0, 0),
    diff_insert: :green,
    diff_insert_whitespace: IO.ANSI.color_background(0, 2, 0),

    # CLI formatter
    success: :green,
    invalid: :yellow,
    skipped: :yellow,
    failure: :red,
    error_info: :red,
    extra_info: :cyan,
    location_info: [:bright, :black]
  ]

  defp colors(opts) do
    @default_colors
    |> Keyword.merge(opts[:colors])
    |> Keyword.put_new(:enabled, IO.ANSI.enabled?())
  end

  defp print_logs(""), do: nil

  defp print_logs(output) do
    indent = "\n     "
    output = String.replace(output, "\n", indent)
    puts_line(["     The following output was logged:", indent | output], newline_sequence())
  end

  defp newline_sequence do
    # We only emit CRLF when writing directly to a terminal. In CI/log capture,
    # `\r` can show up as `^M`, so keep plain `\n` there.
    #
    # `IO.ANSI.enabled?/0` is used as a secondary signal because some
    # environments report `terminal: false` even when running interactively.
    ansi_enabled? = IO.ANSI.enabled?()

    case :io.getopts(:standard_io) do
      opts when is_list(opts) ->
        if Keyword.get(opts, :terminal, false) == true or ansi_enabled? do
          "\r\n"
        else
          "\n"
        end

      {:ok, opts} when is_list(opts) ->
        if Keyword.get(opts, :terminal, false) == true or ansi_enabled? do
          "\r\n"
        else
          "\n"
        end

      _ ->
        "\n"
    end
  end

  defp puts_line(data, "\n"), do: IO.puts(data)

  defp puts_line(data, "\r\n") do
    data
    |> IO.iodata_to_binary()
    |> String.replace("\r\n", "\n")
    |> String.replace("\n", "\r\n")
    |> then(&IO.write([&1, "\r\n"]))
  end

  defp convert_newlines(text, %{newline: "\r\n"}) when is_binary(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\n", "\r\n")
  end

  defp convert_newlines(text, _config), do: text
end
