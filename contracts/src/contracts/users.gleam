import gleam/dynamic/decode
import gleam/json
import shizo_rpc

pub type User {
  User(id: Int, email: String, name: String)
}

fn user_to_json(user: User) -> json.Json {
  let User(id:, email:, name:) = user
  json.object([
    #("id", json.int(id)),
    #("email", json.string(email)),
    #("name", json.string(name)),
  ])
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(User(id:, email:, name:))
}

pub type CreateUserRequest {
  CreateUserRequest(email: String, name: String, password: String)
}

fn create_user_request_codec() {
  shizo_rpc.Codec(create_user_request_to_json, create_user_request_decoder())
}

fn create_user_request_to_json(
  create_user_request: CreateUserRequest,
) -> json.Json {
  let CreateUserRequest(email:, name:, password:) = create_user_request
  json.object([
    #("email", json.string(email)),
    #("name", json.string(name)),
    #("password", json.string(password)),
  ])
}

fn create_user_request_decoder() -> decode.Decoder(CreateUserRequest) {
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateUserRequest(email:, name:, password:))
}

pub type CreateUserResponse {
  CreateUserResponse(user: User)
  EmailTaken
}

fn create_user_response_codec() {
  shizo_rpc.Codec(create_user_response_to_json, create_user_response_decoder())
}

fn create_user_response_to_json(
  create_user_response: CreateUserResponse,
) -> json.Json {
  case create_user_response {
    CreateUserResponse(user:) ->
      json.object([
        #("type", json.string("create_user_response")),
        #("user", user_to_json(user)),
      ])
    EmailTaken ->
      json.object([
        #("type", json.string("email_taken")),
      ])
  }
}

fn create_user_response_decoder() -> decode.Decoder(CreateUserResponse) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "create_user_response" -> {
      use user <- decode.field("user", user_decoder())
      decode.success(CreateUserResponse(user:))
    }
    "email_taken" -> decode.success(EmailTaken)
    _ -> decode.failure(EmailTaken, "CreateUserResponse")
  }
}

pub fn create_user() {
  shizo_rpc.Procedure(
    "create_user",
    create_user_request_codec(),
    create_user_response_codec(),
  )
}

pub type GetUserRequest {
  GetUserRequest(jwt: String)
}

fn get_user_request_codec() {
  shizo_rpc.Codec(get_user_request_to_json, get_user_request_decoder())
}

fn get_user_request_to_json(get_user_request: GetUserRequest) -> json.Json {
  let GetUserRequest(jwt:) = get_user_request
  json.object([
    #("jwt", json.string(jwt)),
  ])
}

fn get_user_request_decoder() -> decode.Decoder(GetUserRequest) {
  use jwt <- decode.field("jwt", decode.string)
  decode.success(GetUserRequest(jwt:))
}

pub type GetUserResponse {
  GetUserResponse(user: User)
  BadToken
}

fn get_user_response_codec() {
  shizo_rpc.Codec(get_user_response_to_json, get_user_response_decoder())
}

fn get_user_response_to_json(get_user_response: GetUserResponse) -> json.Json {
  case get_user_response {
    GetUserResponse(user:) ->
      json.object([
        #("type", json.string("get_user_response")),
        #("user", user_to_json(user)),
      ])
    BadToken ->
      json.object([
        #("type", json.string("bad_token")),
      ])
  }
}

fn get_user_response_decoder() -> decode.Decoder(GetUserResponse) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "get_user_response" -> {
      use user <- decode.field("user", user_decoder())
      decode.success(GetUserResponse(user:))
    }
    "bad_token" -> decode.success(BadToken)
    _ -> decode.failure(BadToken, "GetUserResponse")
  }
}

pub fn get_user() {
  shizo_rpc.Procedure(
    "get_user",
    get_user_request_codec(),
    get_user_response_codec(),
  )
}

pub type LoginRequest {
  LoginRequest(email: String, password: String)
}

fn login_request_codec() {
  shizo_rpc.Codec(login_request_to_json, login_request_decoder())
}

fn login_request_to_json(login_request: LoginRequest) -> json.Json {
  let LoginRequest(email:, password:) = login_request
  json.object([
    #("email", json.string(email)),
    #("password", json.string(password)),
  ])
}

fn login_request_decoder() -> decode.Decoder(LoginRequest) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(LoginRequest(email:, password:))
}

pub type LoginResponse {
  LoginResponse(jwt: String)
}

fn login_response_codec() {
  shizo_rpc.Codec(login_response_to_json, login_response_decoder())
}

fn login_response_to_json(login_response: LoginResponse) -> json.Json {
  let LoginResponse(jwt:) = login_response
  json.object([
    #("jwt", json.string(jwt)),
  ])
}

fn login_response_decoder() -> decode.Decoder(LoginResponse) {
  use jwt <- decode.field("jwt", decode.string)
  decode.success(LoginResponse(jwt:))
}

pub fn login() {
  shizo_rpc.Procedure("login", login_request_codec(), login_response_codec())
}
