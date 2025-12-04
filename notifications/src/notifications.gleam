import carotte
import carotte/channel
import carotte/exchange
import carotte/queue
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/json
import gleam/otp/actor
import gleam/result
import mist
import wisp
import wisp/wisp_mist

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

fn booking_update_decoder() -> decode.Decoder(BookingUpdate) {
  use booking_id <- decode.field("booking_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use status <- decode.field("status", decode.string)
  decode.success(BookingUpdate(booking_id:, user_id:, status:))
}

type Message {
  NewEvent(BookingUpdate)
  GetEvents(process.Subject(List(BookingUpdate)))
}

fn on_message(events: List(BookingUpdate), message: Message) {
  case message {
    NewEvent(evt) -> actor.continue([evt, ..events])
    GetEvents(resp) -> {
      process.send(resp, events)
      actor.continue([])
    }
  }
}

pub fn main() {
  let assert Ok(actor) =
    actor.new([])
    |> actor.on_message(on_message)
    |> actor.start

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

  let assert Ok(_) =
    queue.subscribe(channel: ch, queue: "booking_updates", callback: fn(msg, _) {
      let _ =
        json.parse(msg.payload, booking_update_decoder())
        |> result.map(fn(msg) {
          msg
          |> NewEvent
          |> process.send(actor.data, _)
        })
        |> result.map_error(fn(e) { echo e })

      Nil
    })

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp_mist.handler(
      fn(req) {
        use <- wisp.require_method(req, http.Get)

        process.call(actor.data, 1000, GetEvents)
        |> json.array(booking_update_to_json)
        |> json.to_string
        |> wisp.json_response(200)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(3000)
    |> mist.bind("0.0.0.0")
    |> mist.start

  process.sleep_forever()
}
