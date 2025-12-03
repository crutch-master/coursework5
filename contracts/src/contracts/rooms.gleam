import gleam/dynamic/decode
import gleam/json
import shizo_rpc

pub type Room {
  Room(id: Int, name: String, details: String)
}

fn room_to_json(room: Room) -> json.Json {
  let Room(id:, name:, details:) = room
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("details", json.string(details)),
  ])
}

fn room_decoder() -> decode.Decoder(Room) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use details <- decode.field("details", decode.string)
  decode.success(Room(id:, name:, details:))
}

pub type Booking {
  Booking(id: Int, user_name: String, room: Room, start_ts: Int, end_ts: Int)
}

fn booking_to_json(booking: Booking) -> json.Json {
  let Booking(id:, user_name:, room:, start_ts:, end_ts:) = booking
  json.object([
    #("id", json.int(id)),
    #("user_name", json.string(user_name)),
    #("room", room_to_json(room)),
    #("start_ts", json.int(start_ts)),
    #("end_ts", json.int(end_ts)),
  ])
}

fn booking_decoder() -> decode.Decoder(Booking) {
  use id <- decode.field("id", decode.int)
  use user_name <- decode.field("user_name", decode.string)
  use room <- decode.field("room", room_decoder())
  use start_ts <- decode.field("start_ts", decode.int)
  use end_ts <- decode.field("end_ts", decode.int)
  decode.success(Booking(id:, user_name:, room:, start_ts:, end_ts:))
}

pub type GetRoomsRequest {
  GetRoomsRequest
}

fn get_rooms_request_codec() {
  shizo_rpc.Codec(get_rooms_request_to_json, get_rooms_request_decoder())
}

fn get_rooms_request_to_json(get_rooms_request: GetRoomsRequest) -> json.Json {
  json.string("get_rooms_request")
}

fn get_rooms_request_decoder() -> decode.Decoder(GetRoomsRequest) {
  use variant <- decode.then(decode.string)
  case variant {
    "get_rooms_request" -> decode.success(GetRoomsRequest)
    _ -> decode.failure(GetRoomsRequest, "GetRoomsRequest")
  }
}

pub type GetRoomsResponse {
  GetRoomsResponse(rooms: List(Room))
}

fn get_rooms_response_codec() {
  shizo_rpc.Codec(get_rooms_response_to_json, get_rooms_response_decoder())
}

fn get_rooms_response_to_json(get_rooms_response: GetRoomsResponse) -> json.Json {
  let GetRoomsResponse(rooms:) = get_rooms_response
  json.object([
    #("rooms", json.array(rooms, room_to_json)),
  ])
}

fn get_rooms_response_decoder() -> decode.Decoder(GetRoomsResponse) {
  use rooms <- decode.field("rooms", decode.list(room_decoder()))
  decode.success(GetRoomsResponse(rooms:))
}

pub fn get_rooms() {
  shizo_rpc.Procedure(
    "get_rooms",
    get_rooms_request_codec(),
    get_rooms_response_codec(),
  )
}

pub type GetBookingsRequest {
  GetBookingsRequest(room_id: Int, from_ts: Int, to_ts: Int)
}

fn get_bookings_request_codec() {
  shizo_rpc.Codec(get_bookings_request_to_json, get_bookings_request_decoder())
}

fn get_bookings_request_to_json(
  get_bookings_request: GetBookingsRequest,
) -> json.Json {
  let GetBookingsRequest(room_id:, from_ts:, to_ts:) = get_bookings_request
  json.object([
    #("room_id", json.int(room_id)),
    #("from_ts", json.int(from_ts)),
    #("to_ts", json.int(to_ts)),
  ])
}

fn get_bookings_request_decoder() -> decode.Decoder(GetBookingsRequest) {
  use room_id <- decode.field("room_id", decode.int)
  use from_ts <- decode.field("from_ts", decode.int)
  use to_ts <- decode.field("to_ts", decode.int)
  decode.success(GetBookingsRequest(room_id:, from_ts:, to_ts:))
}

pub type GetBookingsResponse {
  GetBookingsResponse(bookings: List(Booking))
}

fn get_bookings_response_codec() {
  shizo_rpc.Codec(
    get_bookings_response_to_json,
    get_bookings_response_decoder(),
  )
}

fn get_bookings_response_to_json(
  get_bookings_response: GetBookingsResponse,
) -> json.Json {
  let GetBookingsResponse(bookings:) = get_bookings_response
  json.object([
    #("bookings", json.array(bookings, booking_to_json)),
  ])
}

fn get_bookings_response_decoder() -> decode.Decoder(GetBookingsResponse) {
  use bookings <- decode.field("bookings", decode.list(booking_decoder()))
  decode.success(GetBookingsResponse(bookings:))
}

pub fn get_bookings() -> shizo_rpc.Procedure(
  GetBookingsRequest,
  GetBookingsResponse,
) {
  shizo_rpc.Procedure(
    "get_bookings",
    get_bookings_request_codec(),
    get_bookings_response_codec(),
  )
}

pub type GetUserBookingsRequest {
  GetUserBookingsRequest(user_id: Int)
}

fn get_user_bookings_request_codec() {
  shizo_rpc.Codec(
    get_user_bookings_request_to_json,
    get_user_bookings_request_decoder(),
  )
}

fn get_user_bookings_request_to_json(
  get_user_bookings_request: GetUserBookingsRequest,
) -> json.Json {
  let GetUserBookingsRequest(user_id:) = get_user_bookings_request
  json.object([
    #("user_id", json.int(user_id)),
  ])
}

fn get_user_bookings_request_decoder() -> decode.Decoder(GetUserBookingsRequest) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(GetUserBookingsRequest(user_id:))
}

pub fn get_user_bookings() {
  shizo_rpc.Procedure(
    "get_user_bookings",
    get_user_bookings_request_codec(),
    get_bookings_response_codec(),
  )
}

pub type PlaceBookingRequest {
  PlaceBookingRequest(user_id: Int, room_id: Int, start_ts: Int, end_ts: Int)
}

fn place_booking_request_codec() {
  shizo_rpc.Codec(
    place_booking_request_to_json,
    place_booking_request_decoder(),
  )
}

fn place_booking_request_to_json(
  place_booking_request: PlaceBookingRequest,
) -> json.Json {
  let PlaceBookingRequest(user_id:, room_id:, start_ts:, end_ts:) =
    place_booking_request
  json.object([
    #("user_id", json.int(user_id)),
    #("room_id", json.int(room_id)),
    #("start_ts", json.int(start_ts)),
    #("end_ts", json.int(end_ts)),
  ])
}

fn place_booking_request_decoder() -> decode.Decoder(PlaceBookingRequest) {
  use user_id <- decode.field("user_id", decode.int)
  use room_id <- decode.field("room_id", decode.int)
  use start_ts <- decode.field("start_ts", decode.int)
  use end_ts <- decode.field("end_ts", decode.int)
  decode.success(PlaceBookingRequest(user_id:, room_id:, start_ts:, end_ts:))
}

pub type PlaceBookingResponse {
  BookingPlaced
  ErrAlreadyBooked
}

fn place_booking_response_codec() {
  shizo_rpc.Codec(
    place_booking_response_to_json,
    place_booking_response_decoder(),
  )
}

fn place_booking_response_to_json(
  place_booking_response: PlaceBookingResponse,
) -> json.Json {
  case place_booking_response {
    BookingPlaced -> json.string("booking_placed")
    ErrAlreadyBooked -> json.string("err_already_booked")
  }
}

fn place_booking_response_decoder() -> decode.Decoder(PlaceBookingResponse) {
  use variant <- decode.then(decode.string)
  case variant {
    "booking_placed" -> decode.success(BookingPlaced)
    "err_already_booked" -> decode.success(ErrAlreadyBooked)
    _ -> decode.failure(BookingPlaced, "PlaceBookingResponse")
  }
}

pub fn place_booking() -> shizo_rpc.Procedure(
  PlaceBookingRequest,
  PlaceBookingResponse,
) {
  shizo_rpc.Procedure(
    "place_booking",
    place_booking_request_codec(),
    place_booking_response_codec(),
  )
}

pub type CancelBookingRequest {
  CancelBookingRequest(user_id: Int, booking_id: Int)
}

fn cancel_booking_request_codec() {
  shizo_rpc.Codec(
    cancel_booking_request_to_json,
    cancel_booking_request_decoder(),
  )
}

fn cancel_booking_request_to_json(
  cancel_booking_request: CancelBookingRequest,
) -> json.Json {
  let CancelBookingRequest(user_id:, booking_id:) = cancel_booking_request
  json.object([
    #("user_id", json.int(user_id)),
    #("booking_id", json.int(booking_id)),
  ])
}

fn cancel_booking_request_decoder() -> decode.Decoder(CancelBookingRequest) {
  use user_id <- decode.field("user_id", decode.int)
  use booking_id <- decode.field("booking_id", decode.int)
  decode.success(CancelBookingRequest(user_id:, booking_id:))
}

pub type CancelBookingResponse {
  BookingCancelled
  NoBookingFound
}

fn cancel_booking_response_codec() {
  shizo_rpc.Codec(
    cancel_booking_response_to_json,
    cancel_booking_response_decoder(),
  )
}

fn cancel_booking_response_to_json(
  cancel_booking_response: CancelBookingResponse,
) -> json.Json {
  case cancel_booking_response {
    BookingCancelled -> json.string("booking_cancelled")
    NoBookingFound -> json.string("no_booking_found")
  }
}

fn cancel_booking_response_decoder() -> decode.Decoder(CancelBookingResponse) {
  use variant <- decode.then(decode.string)
  case variant {
    "booking_cancelled" -> decode.success(BookingCancelled)
    "no_booking_found" -> decode.success(NoBookingFound)
    _ -> decode.failure(BookingCancelled, "CancelBookingResponse")
  }
}

pub fn cancel_booking() {
  shizo_rpc.Procedure(
    "cancel_booking",
    cancel_booking_request_codec(),
    cancel_booking_response_codec(),
  )
}
