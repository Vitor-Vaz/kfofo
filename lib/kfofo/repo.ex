defmodule Kfofo.Repo do
  use Ecto.Repo,
    otp_app: :kfofo,
    adapter: Ecto.Adapters.Postgres
end
