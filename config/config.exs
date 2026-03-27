import Config

config :giza_sphinxsearch,
  host: "localhost",
  port: 9312,
  sql_port: 9306

import_config "#{config_env()}.exs"
