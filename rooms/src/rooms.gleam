import carotte
import carotte/channel
import carotte/exchange
import carotte/publisher
import carotte/queue
import contracts/rooms
import envoy
import gleam/erlang/process
import gleam/float
import gleam/json
import gleam/list
import gleam/result
import gleam/time/timestamp
import glisten/socket/options
import glisten/tcp
import pog
import rooms/sql
import shizo_rpc
import shizo_rpc/server

fn get_rooms() {
  use conn, _ <- shizo_rpc.Handler(rooms.get_rooms())

  {
    use rooms <- result.try(
      sql.get_rooms(pog.named_connection(conn))
      |> result.map_error(fn(_) { rooms.GetRoomsResponse([]) }),
    )

    use row: sql.GetRoomsRow <-
      fn(f) { Ok(rooms.GetRoomsResponse(list.map(rooms.rows, f))) }

    rooms.Room(row.id, row.name, row.details)
  }
  |> result.unwrap_both
}

pub fn get_bookings() {
  use conn, req <- shizo_rpc.Handler(rooms.get_bookings())

  {
    use bookings <- result.try(
      sql.get_bookings(
        pog.named_connection(conn),
        timestamp.from_unix_seconds(req.from_ts),
        timestamp.from_unix_seconds(req.to_ts),
        req.room_id,
      )
      |> result.map_error(fn(_) { rooms.GetBookingsResponse([]) }),
    )

    use row: sql.GetBookingsRow <-
      fn(f) { Ok(rooms.GetBookingsResponse(list.map(bookings.rows, f))) }

    rooms.Booking(
      row.id,
      row.user_name,
      rooms.Room(row.room_id, row.room_name, row.details),
      timestamp.to_unix_seconds(row.start_time)
        |> float.round,
      timestamp.to_unix_seconds(row.end_time)
        |> float.round,
    )
  }
  |> result.unwrap_both()
}

pub fn get_user_bookings() {
  use conn, req <- shizo_rpc.Handler(rooms.get_user_bookings())

  {
    use bookings <- result.try(
      sql.get_user_bookings(pog.named_connection(conn), req.user_id)
      |> result.map_error(fn(_) { rooms.GetBookingsResponse([]) }),
    )

    use row: sql.GetUserBookingsRow <-
      fn(f) { Ok(rooms.GetBookingsResponse(list.map(bookings.rows, f))) }

    rooms.Booking(
      row.id,
      row.user_name,
      rooms.Room(row.room_id, row.room_name, row.details),
      timestamp.to_unix_seconds(row.start_time)
        |> float.round,
      timestamp.to_unix_seconds(row.end_time)
        |> float.round,
    )
  }
  |> result.unwrap_both()
}

type BookingUpdate {
  BookingUpdate(booking_id: Int, user_id: Int, status: String)
}

fn booking_update_to_json(booking_update: BookingUpdate) -> json.Json {
  let BookingUpdate(booking_id:, user_id:, status:) = booking_update
  json.object([
    #("booking_id", json.int(booking_id)),
    #("user_id", json.int(user_id)),
    #("status", json.string(status)),
  ])
}

pub fn cancel_booking() {
  use #(conn, ch), req <- shizo_rpc.Handler(rooms.cancel_booking())

  {
    use rows <- result.try(
      sql.cancel_booking(
        pog.named_connection(conn),
        req.booking_id,
        req.user_id,
      )
      |> result.map_error(fn(_) { rooms.NoBookingFound }),
    )

    case rows {
      pog.Returned(count: 1, rows: [count]) ->
        case count.count {
          1 -> {
            let _ =
              publisher.publish(
                ch,
                "bookings",
                "bookings",
                BookingUpdate(
                  booking_id: req.booking_id,
                  user_id: req.user_id,
                  status: "cancelled",
                )
                  |> booking_update_to_json
                  |> json.to_string,
                [],
              )
              |> result.map_error(fn(e) { echo e })

            rooms.BookingCancelled
          }
          _ -> rooms.NoBookingFound
        }
      _ -> rooms.NoBookingFound
    }
    |> Ok
  }
  |> result.unwrap_both()
}

pub fn place_booking() {
  use #(conn, ch), req <- shizo_rpc.Handler(rooms.place_booking())

  {
    use rows <- result.try(
      sql.booking_taken(
        pog.named_connection(conn),
        req.room_id,
        req.start_ts |> timestamp.from_unix_seconds,
        req.end_ts |> timestamp.from_unix_seconds,
      )
      |> result.map_error(fn(_) { rooms.ErrAlreadyBooked }),
    )

    use <-
      fn(f) {
        case rows {
          pog.Returned(count: 1, rows: [taken]) ->
            case taken.exists {
              False -> f()
              _ -> Ok(rooms.ErrAlreadyBooked)
            }
          _ -> Ok(rooms.ErrAlreadyBooked)
        }
      }

    use rows <- result.try(
      sql.place_booking(
        pog.named_connection(conn),
        req.user_id,
        req.room_id,
        req.start_ts |> timestamp.from_unix_seconds,
        req.end_ts |> timestamp.from_unix_seconds,
      )
      |> result.map_error(fn(_) { rooms.ErrAlreadyBooked }),
    )

    let _ =
      rows.rows
      |> list.first
      |> result.map(fn(row) {
        publisher.publish(
          ch,
          "bookings",
          "bookings",
          BookingUpdate(
            booking_id: row.id,
            user_id: req.user_id,
            status: "placed",
          )
            |> booking_update_to_json
            |> json.to_string,
          [],
        )
        |> result.map_error(fn(e) { echo e })
      })

    rooms.BookingPlaced |> Ok
  }
  |> result.unwrap_both()
}

pub fn main() {
  let pool_name = process.new_name("pool")
  let assert Ok(Ok(_)) =
    envoy.get("DATABASE_URL")
    |> result.try(pog.url_config(pool_name, _))
    |> result.map(pog.pool_size(_, 4))
    |> result.map(pog.start)

  let assert Ok(rabbit_host) = envoy.get("RABBIT_HOST")
  let assert Ok(client) =
    carotte.default_client()
    |> carotte.with_host(rabbit_host)
    |> carotte.with_port(5672)
    |> carotte.start()

  let assert Ok(ch) = channel.open_channel(client)

  let assert Ok(_) =
    exchange.new("bookings")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(ch)

  let assert Ok(_) =
    queue.new("booking_updates")
    |> queue.as_durable()
    |> queue.declare(ch)

  let assert Ok(_) =
    queue.bind(
      channel: ch,
      queue: "booking_updates",
      exchange: "bookings",
      routing_key: "bookings",
    )

  let assert Ok(socket) =
    tcp.listen(3000, [options.ActiveMode(options.Passive)])

  [
    get_rooms() |> server.to_tcp_handler(pool_name),
    get_bookings() |> server.to_tcp_handler(pool_name),
    get_user_bookings() |> server.to_tcp_handler(pool_name),
    cancel_booking() |> server.to_tcp_handler(#(pool_name, ch)),
    place_booking() |> server.to_tcp_handler(#(pool_name, ch)),
  ]
  |> server.start(socket)
}
