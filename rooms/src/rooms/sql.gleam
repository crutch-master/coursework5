//// This module contains the code to run the sql queries defined in
//// `./src/rooms/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `booking_taken` query
/// defined in `./src/rooms/sql/booking_taken.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type BookingTakenRow {
  BookingTakenRow(exists: Bool)
}

/// Runs the `booking_taken` query
/// defined in `./src/rooms/sql/booking_taken.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn booking_taken(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(BookingTakenRow), pog.QueryError) {
  let decoder = {
    use exists <- decode.field(0, decode.bool)
    decode.success(BookingTakenRow(exists:))
  }

  "select exists(
  select 1
  from bookings
  where room_id = $1
  and end_time > $2
  and start_time < $3
  and status = 'confirmed'
);
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cancel_booking` query
/// defined in `./src/rooms/sql/cancel_booking.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CancelBookingRow {
  CancelBookingRow(count: Int)
}

/// Runs the `cancel_booking` query
/// defined in `./src/rooms/sql/cancel_booking.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cancel_booking(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(CancelBookingRow), pog.QueryError) {
  let decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(CancelBookingRow(count:))
  }

  "with rows as (
  update bookings
  set status = 'cancelled'
  where id = $1 and user_id = $2
  returning 1
)
select count(*) from rows;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_bookings` query
/// defined in `./src/rooms/sql/get_bookings.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetBookingsRow {
  GetBookingsRow(
    id: Int,
    user_name: String,
    room_id: Int,
    room_name: String,
    details: String,
    start_time: Timestamp,
    end_time: Timestamp,
  )
}

/// Runs the `get_bookings` query
/// defined in `./src/rooms/sql/get_bookings.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_bookings(
  db: pog.Connection,
  arg_1: Timestamp,
  arg_2: Timestamp,
  arg_3: Int,
) -> Result(pog.Returned(GetBookingsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_name <- decode.field(1, decode.string)
    use room_id <- decode.field(2, decode.int)
    use room_name <- decode.field(3, decode.string)
    use details <- decode.field(4, decode.string)
    use start_time <- decode.field(5, pog.timestamp_decoder())
    use end_time <- decode.field(6, pog.timestamp_decoder())
    decode.success(GetBookingsRow(
      id:,
      user_name:,
      room_id:,
      room_name:,
      details:,
      start_time:,
      end_time:,
    ))
  }

  "select
  bookings.id,
  users.name as user_name,
  rooms.id as room_id,
  rooms.name as room_name,
  rooms.details,
  bookings.start_time,
  bookings.end_time
from bookings
inner join users on bookings.user_id = users.id
inner join rooms on bookings.room_id = rooms.id
where start_time between $1 and $2
and room_id = $3
and status = 'confirmed';
"
  |> pog.query
  |> pog.parameter(pog.timestamp(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_rooms` query
/// defined in `./src/rooms/sql/get_rooms.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetRoomsRow {
  GetRoomsRow(id: Int, name: String, details: String)
}

/// Runs the `get_rooms` query
/// defined in `./src/rooms/sql/get_rooms.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_rooms(
  db: pog.Connection,
) -> Result(pog.Returned(GetRoomsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use details <- decode.field(2, decode.string)
    decode.success(GetRoomsRow(id:, name:, details:))
  }

  "select *
from rooms;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user_bookings` query
/// defined in `./src/rooms/sql/get_user_bookings.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserBookingsRow {
  GetUserBookingsRow(
    id: Int,
    user_name: String,
    room_id: Int,
    room_name: String,
    details: String,
    start_time: Timestamp,
    end_time: Timestamp,
  )
}

/// Runs the `get_user_bookings` query
/// defined in `./src/rooms/sql/get_user_bookings.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user_bookings(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetUserBookingsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_name <- decode.field(1, decode.string)
    use room_id <- decode.field(2, decode.int)
    use room_name <- decode.field(3, decode.string)
    use details <- decode.field(4, decode.string)
    use start_time <- decode.field(5, pog.timestamp_decoder())
    use end_time <- decode.field(6, pog.timestamp_decoder())
    decode.success(GetUserBookingsRow(
      id:,
      user_name:,
      room_id:,
      room_name:,
      details:,
      start_time:,
      end_time:,
    ))
  }

  "select
  bookings.id,
  users.name as user_name,
  rooms.id as room_id,
  rooms.name as room_name,
  rooms.details,
  bookings.start_time,
  bookings.end_time
from bookings
inner join users on bookings.user_id = users.id
inner join rooms on bookings.room_id = rooms.id
where user_id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `place_booking` query
/// defined in `./src/rooms/sql/place_booking.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn place_booking(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Timestamp,
  arg_4: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into bookings (
  user_id, 
  room_id,
  status,
  start_time,
  end_time
) values ($1, $2, 'confirmed', $3, $4);
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.timestamp(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
