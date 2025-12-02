//// This module contains the code to run the sql queries defined in
//// `./src/users/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// A row you get from running the `create_user` query
/// defined in `./src/users/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(id: Int, email: String, name: String, password_hash: BitArray)
}

/// Runs the `create_user` query
/// defined in `./src/users/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: BitArray,
) -> Result(pog.Returned(CreateUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use password_hash <- decode.field(3, decode.bit_array)
    decode.success(CreateUserRow(id:, email:, name:, password_hash:))
  }

  "insert into users (email, name, password_hash)
values ($1, $2, $3)
returning *;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.bytea(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user_for_email` query
/// defined in `./src/users/sql/get_user_for_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserForEmailRow {
  GetUserForEmailRow(
    id: Int,
    email: String,
    name: String,
    password_hash: BitArray,
  )
}

/// Runs the `get_user_for_email` query
/// defined in `./src/users/sql/get_user_for_email.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user_for_email(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(GetUserForEmailRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use password_hash <- decode.field(3, decode.bit_array)
    decode.success(GetUserForEmailRow(id:, email:, name:, password_hash:))
  }

  "select * from users 
where email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user_for_id` query
/// defined in `./src/users/sql/get_user_for_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserForIdRow {
  GetUserForIdRow(id: Int, email: String, name: String, password_hash: BitArray)
}

/// Runs the `get_user_for_id` query
/// defined in `./src/users/sql/get_user_for_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user_for_id(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetUserForIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use password_hash <- decode.field(3, decode.bit_array)
    decode.success(GetUserForIdRow(id:, email:, name:, password_hash:))
  }

  "select * from users 
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
