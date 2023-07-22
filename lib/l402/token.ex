defmodule L402.Token do
    use Joken.Config

    #def signer(), do: Joken.Signer.create("HS256", "supersecret")

    @impl Joken.Config
    def token_config() do
        defaults = [
            default_exp: 24 * 60 * 60,
            iss: "my-web-service"
        ]

        defaults
        |> default_claims()
    end

    def get_jwt(payment_hash) do
        extra_claims = %{"payment_hash" => payment_hash}
        {:ok, token, claims} = token_config()
            |> Joken.generate_and_sign(extra_claims)

        IO.inspect(claims)
        {:ok, token}
    end

end