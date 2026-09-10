release: MIX_ENV=prod mix do ecto.create || true && mix ecto.migrate && MIX_ENV=prod mix rabbitmq.declare
web: MIX_ENV=prod mix phx.server