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

pub fn create_user_request_decoder() -> decode.Decoder(CreateUserRequest) {
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateUserRequest(email:, name:, password:))
}

pub type CreateUserResponse {
  CreateUserResponse(user: User)
  CreateUserErrEmailTaken
}

fn create_user_response_codec() {
  shizo_rpc.Codec(create_user_response_to_json, create_user_response_decoder())
}

pub fn create_user_response_to_json(
  create_user_response: CreateUserResponse,
) -> json.Json {
  case create_user_response {
    CreateUserResponse(user:) ->
      json.object([
        #("type", json.string("create_user_response")),
        #("user", user_to_json(user)),
      ])
    CreateUserErrEmailTaken ->
      json.object([
        #("type", json.string("create_user_err_email_taken")),
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
    "create_user_err_email_taken" -> decode.success(CreateUserErrEmailTaken)
    _ -> decode.failure(CreateUserErrEmailTaken, "CreateUserResponse")
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

pub fn get_user_request_decoder() -> decode.Decoder(GetUserRequest) {
  use jwt <- decode.field("jwt", decode.string)
  decode.success(GetUserRequest(jwt:))
}

pub type GetUserResponse {
  GetUserResponse(user: User)
  GetUserErrBadToken
  GetUserErrNoUser
}

fn get_user_response_codec() {
  shizo_rpc.Codec(get_user_response_to_json, get_user_response_decoder())
}

pub fn get_user_response_to_json(
  get_user_response: GetUserResponse,
) -> json.Json {
  case get_user_response {
    GetUserResponse(user:) ->
      json.object([
        #("type", json.string("get_user_response")),
        #("user", user_to_json(user)),
      ])
    GetUserErrBadToken ->
      json.object([
        #("type", json.string("get_user_err_bad_token")),
      ])
    GetUserErrNoUser ->
      json.object([
        #("type", json.string("get_user_err_no_user")),
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
    "get_user_err_bad_token" -> decode.success(GetUserErrBadToken)
    "get_user_err_no_user" -> decode.success(GetUserErrNoUser)
    _ -> decode.failure(GetUserErrNoUser, "GetUserResponse")
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

pub fn login_request_decoder() -> decode.Decoder(LoginRequest) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(LoginRequest(email:, password:))
}

pub type LoginResponse {
  LoginResponse(jwt: String)
  LoginErrNoUser
  LoginErrBadCreds
}

fn login_response_codec() {
  shizo_rpc.Codec(login_response_to_json, login_response_decoder())
}

pub fn login_response_to_json(login_response: LoginResponse) -> json.Json {
  case login_response {
    LoginResponse(jwt:) ->
      json.object([
        #("type", json.string("login_response")),
        #("jwt", json.string(jwt)),
      ])
    LoginErrNoUser ->
      json.object([
        #("type", json.string("login_err_no_user")),
      ])
    LoginErrBadCreds ->
      json.object([
        #("type", json.string("login_err_bad_creds")),
      ])
  }
}

fn login_response_decoder() -> decode.Decoder(LoginResponse) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "login_response" -> {
      use jwt <- decode.field("jwt", decode.string)
      decode.success(LoginResponse(jwt:))
    }
    "login_err_no_user" -> decode.success(LoginErrNoUser)
    "login_err_bad_creds" -> decode.success(LoginErrBadCreds)
    _ -> decode.failure(LoginErrNoUser, "LoginResponse")
  }
}

pub fn login() {
  shizo_rpc.Procedure("login", login_request_codec(), login_response_codec())
}

pub type ValidateTokenResponse {
  ValidateTokenResponse(user_id: Int)
  ValidateTokenErrBadToken
}

fn validate_token_response_codec() {
  shizo_rpc.Codec(
    validate_token_response_to_json,
    validate_token_response_decoder(),
  )
}

fn validate_token_response_to_json(
  validate_token_response: ValidateTokenResponse,
) -> json.Json {
  case validate_token_response {
    ValidateTokenResponse(user_id:) ->
      json.object([
        #("type", json.string("validate_token_response")),
        #("user_id", json.int(user_id)),
      ])
    ValidateTokenErrBadToken ->
      json.object([
        #("type", json.string("validate_token_err_bad_token")),
      ])
  }
}

fn validate_token_response_decoder() -> decode.Decoder(ValidateTokenResponse) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "validate_token_response" -> {
      use user_id <- decode.field("user_id", decode.int)
      decode.success(ValidateTokenResponse(user_id:))
    }
    "validate_token_err_bad_token" -> decode.success(ValidateTokenErrBadToken)
    _ -> decode.failure(ValidateTokenErrBadToken, "ValidateTokenResponse")
  }
}

pub fn validate_token() {
  shizo_rpc.Procedure(
    "validate_token",
    get_user_request_codec(),
    validate_token_response_codec(),
  )
}
