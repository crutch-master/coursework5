import birl
import birl/duration
import contracts/users
import envoy
import gleam/bit_array
import gleam/crypto
import gleam/erlang/process
import gleam/int
import gleam/result
import glisten/socket/options
import glisten/tcp
import gwt
import pog
import shizo_rpc
import shizo_rpc/server
import users/sql

fn hash_password(password) {
  crypto.hash(crypto.Sha256, bit_array.from_string(password))
}

fn create_user_handler() {
  use conn, req <- shizo_rpc.Handler(users.create_user())
  let conn = pog.named_connection(conn)

  case sql.create_user(conn, req.email, req.name, hash_password(req.password)) {
    Ok(pog.Returned(count: 1, rows: [user])) ->
      users.CreateUserResponse(user: users.User(user.id, user.email, user.name))
    Error(pog.ConstraintViolated(_, _, _)) -> users.CreateUserErrEmailTaken
    _ -> panic
  }
}

fn validate_jwt(jwt, secret) {
  jwt
  |> gwt.from_signed_string(secret)
  |> result.try(gwt.get_subject)
  |> result.map_error(fn(_) { Nil })
  |> result.try(int.parse)
}

fn validate_toke_handler() {
  use secret, req <- shizo_rpc.Handler(users.validate_token())

  case validate_jwt(req.jwt, secret) {
    Ok(id) -> users.ValidateTokenResponse(id)
    Error(_) -> users.ValidateTokenErrBadToken
  }
}

fn login_handler() {
  use #(conn, secret), req <- shizo_rpc.Handler(users.login())

  {
    use user <- result.try(
      sql.get_user_for_email(pog.named_connection(conn), req.email)
      |> result.map_error(fn(_) { panic })
      |> result.try(fn(user) {
        case user {
          pog.Returned(count: 1, rows: [user]) -> Ok(user)
          _ -> Error(users.LoginErrNoUser)
        }
      }),
    )

    use <-
      fn(f) {
        case hash_password(req.password) == user.password_hash {
          True -> f()
          False -> Error(users.LoginErrBadCreds)
        }
      }

    gwt.new()
    |> gwt.set_subject(int.to_string(user.id))
    |> gwt.set_expiration(
      birl.now()
      |> birl.add(duration.hours(1))
      |> birl.to_unix,
    )
    |> gwt.to_signed_string(gwt.HS256, secret)
    |> users.LoginResponse
    |> Ok
  }
  |> result.unwrap_both
}

fn get_user_handler() {
  use #(conn, secret), req <- shizo_rpc.Handler(users.get_user())

  {
    use user_id <- result.try(
      validate_jwt(req.jwt, secret)
      |> result.map_error(fn(_) { users.GetUserErrBadToken }),
    )

    use user <- result.try(
      sql.get_user_for_id(pog.named_connection(conn), user_id)
      |> result.map_error(fn(_) { panic })
      |> result.try(fn(user) {
        case user {
          pog.Returned(count: 1, rows: [user]) -> Ok(user)
          _ -> Error(users.GetUserErrNoUser)
        }
      }),
    )

    users.GetUserResponse(user: users.User(
      id: user.id,
      name: user.name,
      email: user.email,
    ))
    |> Ok
  }
  |> result.unwrap_both
}

pub fn main() {
  let secret = "pivo"
  let pool_name = process.new_name("pool")
  let assert Ok(Ok(_)) =
    envoy.get("DATABASE_URL")
    |> result.try(pog.url_config(pool_name, _))
    |> result.map(pog.pool_size(_, 4))
    |> result.map(pog.start)

  let assert Ok(socket) =
    tcp.listen(3000, [options.ActiveMode(options.Passive)])

  [
    create_user_handler() |> server.to_tcp_handler(pool_name),
    validate_toke_handler() |> server.to_tcp_handler(secret),
    login_handler() |> server.to_tcp_handler(#(pool_name, secret)),
    get_user_handler() |> server.to_tcp_handler(#(pool_name, secret)),
  ]
  |> server.start(socket)
}
