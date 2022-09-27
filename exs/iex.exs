# mix run exs/iex.exs
# four arrow keys show as ^[[C^[[D^[[B^[[A
# in both IO.gets and IEx.start

IO.inspect(:init.get_arguments())
IO.inspect(Application.get_env(:elixir, :ansi_enabled))
IO.gets(">")
IEx.start()

# wait without messing with stdio
receive do
  any -> IO.inspect(any)
end
