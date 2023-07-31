import Config

config :l402,
  admin_macaroon_path: System.get_env("ADMIN_MAC"),
  cert_path: System.get_env("CERT_PATH")

config :grpc,
  host: System.get_env("HOST") || "127.0.0.1",
  port: System.get_env("PORT") || 10009
