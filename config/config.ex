import Config

config :l402,
    :admin_macaroon_path, ""
    :cert_path, ""

config :grpc,
  start_server: true,
  host: System.get_env("HOST") || "127.0.0.1",
  port: System.get_env("PORT") || "10002"
