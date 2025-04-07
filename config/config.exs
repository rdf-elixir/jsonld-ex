import Config

import_config "#{Mix.env()}.exs"

config :tesla, :adapter, Tesla.Adapter.Hackney
