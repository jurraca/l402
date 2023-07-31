defmodule L402.Endpoint do
  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger, level: :debug)
  run(L402.Server)
end
