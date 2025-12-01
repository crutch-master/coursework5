create table if not exists users (
  id bigserial primary key,
  email text not null,
  name text not null
);

create table if not exists rooms (
  id bigserial primary key,
  name text not null,
  details jsonb not null
);

create type booking_status as enum (
  'confirmed',
  'cancelled'
);

create table if not exists bookings (
  id bigserial primary key,
  user_id bigint not null,
  room_id bigint not null,
  status booking_status not null,
  start_time timestamp not null,
  end_time timestamp not null
);

create index if not exists bookings_room_time_idx
  on bookings (room_id, start_time, end_time)
  where status = 'confirmed';

create index if not exists bookings_room_idx
  on bookings (room_id, start_time);

create index if not exists bookings_user_idx
  on bookings (user_id, start_time);
