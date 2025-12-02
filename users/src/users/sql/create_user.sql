insert into users (email, name, password_hash)
values ($1, $2, $3)
returning *;
