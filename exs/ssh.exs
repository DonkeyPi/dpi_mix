# mix run exs/ssh.exs
# four arrow keys show as ^[[C^[[D^[[B^[[A

:ok = :ssh.start()
opts = [silently_accept_hosts: true]
{:ok, _} = :ssh.shell('localhost', opts)
