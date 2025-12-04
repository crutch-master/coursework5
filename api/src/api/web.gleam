import contracts/rooms
import contracts/users
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/result
import shizo_rpc/client
import wisp

pub type Context {
  Context(users: client.Client, rooms: client.Client)
}

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
}

pub fn create_user(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let got = {
    use req <- result.try(
      decode.run(json, users.create_user_request_decoder())
      |> result.map_error(fn(_) { Nil }),
    )

    use response <- result.try(client.call(ctx.users, users.create_user(), req))

    response |> users.create_user_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 201)
    Error(_) -> wisp.bad_request("")
  }
}

pub fn login(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let got = {
    use req <- result.try(
      decode.run(json, users.login_request_decoder())
      |> result.map_error(fn(_) { Nil }),
    )

    use response <- result.try(client.call(ctx.users, users.login(), req))

    response |> users.login_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 201)
    Error(_) -> wisp.bad_request("")
  }
}

fn get_jwt(req: wisp.Request, f: fn(String) -> wisp.Response) -> wisp.Response {
  list.find(req.headers, fn(a) { a.0 == "authorization" })
  |> result.map(fn(a) { f(a.1) })
  |> result.map_error(fn(_) { wisp.response(401) })
  |> result.unwrap_both
}

pub fn get_user(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  use jwt <- get_jwt(req)

  let got = {
    use response <- result.try(client.call(
      ctx.users,
      users.get_user(),
      users.GetUserRequest(jwt),
    ))

    response |> users.get_user_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 200)
    Error(_) -> wisp.bad_request("")
  }
}

fn get_user_id(
  req: wisp.Request,
  ctx: Context,
  f: fn(Int) -> wisp.Response,
) -> wisp.Response {
  use jwt <- get_jwt(req)

  client.call(ctx.users, users.validate_token(), users.GetUserRequest(jwt))
  |> result.map(fn(a) {
    case a {
      users.ValidateTokenResponse(id) -> f(id)
      _ -> wisp.response(401)
    }
  })
  |> result.map_error(fn(_) { wisp.response(401) })
  |> result.unwrap_both
}

pub fn get_rooms(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  let got = {
    use response <- result.try(client.call(
      ctx.rooms,
      rooms.get_rooms(),
      rooms.GetRoomsRequest,
    ))

    response |> rooms.get_rooms_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 200)
    Error(_) -> wisp.bad_request("")
  }
}

pub fn get_bookings(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  use json <- wisp.require_json(req)

  let got = {
    use req <- result.try(
      decode.run(json, rooms.get_bookings_request_decoder())
      |> result.map_error(fn(_) { Nil }),
    )
    use response <- result.try(client.call(ctx.rooms, rooms.get_bookings(), req))

    response |> rooms.get_bookings_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 200)
    Error(_) -> wisp.bad_request("")
  }
}

pub fn get_user_bookings(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  use user_id <- get_user_id(req, ctx)

  let got = {
    use response <- result.try(client.call(
      ctx.rooms,
      rooms.get_user_bookings(),
      rooms.GetUserBookingsRequest(user_id),
    ))

    response |> rooms.get_bookings_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 200)
    Error(_) -> wisp.bad_request("")
  }
}

type PlaceBookingRequest {
  PlaceBookingRequest(room_id: Int, start_ts: Int, end_ts: Int)
}

fn place_booking_request_decoder() -> decode.Decoder(PlaceBookingRequest) {
  use room_id <- decode.field("room_id", decode.int)
  use start_ts <- decode.field("start_ts", decode.int)
  use end_ts <- decode.field("end_ts", decode.int)
  decode.success(PlaceBookingRequest(room_id:, start_ts:, end_ts:))
}

pub fn place_booking(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use user_id <- get_user_id(req, ctx)
  use json <- wisp.require_json(req)

  let got = {
    use req <- result.try(
      decode.run(json, place_booking_request_decoder())
      |> result.map_error(fn(_) { Nil }),
    )

    use response <- result.try(client.call(
      ctx.rooms,
      rooms.place_booking(),
      rooms.PlaceBookingRequest(user_id, req.room_id, req.start_ts, req.end_ts),
    ))

    response |> rooms.place_booking_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 201)
    Error(_) -> wisp.bad_request("")
  }
}

type CancelBookingRequest {
  CancelBookingRequest(booking_id: Int)
}

fn cancel_booking_request_decoder() -> decode.Decoder(CancelBookingRequest) {
  use booking_id <- decode.field("booking_id", decode.int)
  decode.success(CancelBookingRequest(booking_id:))
}

pub fn cancel_booking(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use user_id <- get_user_id(req, ctx)
  use json <- wisp.require_json(req)

  let got = {
    use req <- result.try(
      decode.run(json, cancel_booking_request_decoder())
      |> result.map_error(fn(_) { Nil }),
    )

    use response <- result.try(client.call(
      ctx.rooms,
      rooms.cancel_booking(),
      rooms.CancelBookingRequest(user_id, req.booking_id),
    ))

    response |> rooms.cancel_booking_response_to_json |> json.to_string |> Ok
  }

  case got {
    Ok(resp) -> wisp.json_response(resp, 201)
    Error(_) -> wisp.bad_request("")
  }
}
