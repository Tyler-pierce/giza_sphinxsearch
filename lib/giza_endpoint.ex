defmodule Giza.Endpoint do
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, opts, opts)
	end

	def init(opts) do
		children = [
			{Giza.Service, host: Keyword.get(opts, :host, "localhost"), port: Keyword.get(opts, :port, 9312)}
		]

		children_final = cond do
			Keyword.has_key?(opts, :sql_port) ->
				[{Mariaex, 
				  name: :mysql_sphinx_client, 
				  hostname: Keyword.get(opts, :host, "localhost"), 
				  port: Keyword.get(opts, :sql_port, 9306), 
				  skip_database: true, 
				  sock_type: :tcp}
				  	|children]
			true ->
				children
		end

		Supervisor.init(children_final, strategy: :one_for_one)
	end
end