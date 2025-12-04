import api/router
import api/web
import envoy
import gleam/erlang/process
import mist
import shizo_rpc/client
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(users_host) = envoy.get("USERS_HOST")
  let assert Ok(users) = client.new_client(users_host, 3000)

  let assert Ok(rooms_host) = envoy.get("ROOMS_HOST")
  let assert Ok(rooms) = client.new_client(rooms_host, 3000)

  let ctx = web.Context(users, rooms)

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), secret_key_base)
    |> mist.new
    |> mist.port(3000)
    |> mist.bind("0.0.0.0")
    |> mist.start

  process.sleep_forever()
}
