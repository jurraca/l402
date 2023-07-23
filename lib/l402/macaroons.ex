defmodule L402.Macaroons do
    alias Macaroon.Serializers.Binary.V2
    alias Macaroon.{Types, Verification}

    def decode(bin), do: V2.decode_mac(bin)

    def build([]), do: default()
    def build([caveats: caveats]) do
        default()
        |> append_caveats(caveats)
        |> Macaroon.serialize_v2(:binary)
    end

    def verify(macaroon, predicates, secret_key) do
        params = Types.Verification.VerifyParameters.build([predicates: predicates, callbacks: []])
        Verification.verify(params, macaroon, secret_key)
    end

    def get_payment_hash_from_macaroon(mac) when is_map(mac) do
        case mac |> Map.get(:caveats) |> ph_in_caveats() do
            nil -> {:error, "No payment hash found in caveats"}
            ph -> ph |> String.split("=") |> Enum.at(-1)
        end
    end

    def get_payment_hash_from_macaroon(mac) when is_binary(mac) do
        {:ok, decoded} = decode(mac)
        get_payment_hash_from_macaroon(decoded)
    end

    def verify_caveats(macaroon, payment_hash) do
        case decoded = decode(macaroon) do
            {:ok, %{caveats: caveats}} ->
                verify_payment_hash(caveats, payment_hash)
            {:error, _} = err -> err
            _ -> {:error, "failed caveat decode"}
        end
    end

    def verify_payment_hash(caveats, challenge_hash) do
        ph = ph_in_caveats(caveats)

        if ph do
            "payment_hash = " <> hash = ph
            {:ok, challenge_hash == ph}
        else
            {:error, "No payment hash found in Macaroon caveats"}
        end
    end

    defp ph_in_caveats(caveats) do
        case Enum.filter(caveats, fn cav ->
                cav
                |> Map.values()
                |> String.starts_with?("payment_hash")
            end) do
            [] -> nil
            caveat -> caveat.identifier
        end
    end

    defp default() do
        Macaroon.create_macaroon("my-app", "my-service", "supersecret") #Application.get_env("MAC_SECRET"))
    end

    defp append_caveats(mac, []), do: mac
    defp append_caveats(mac, [{k, v} | tail]) do
        stringified = Atom.to_string(k) <> " = " <> v
        updated_mac = Macaroon.add_first_party_caveat(mac, stringified)
        append_caveats(updated_mac, tail)
    end
end