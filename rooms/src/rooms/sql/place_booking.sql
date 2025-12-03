insert into bookings (
  user_id, 
  room_id,
  status,
  start_time,
  end_time
) values ($1, $2, 'confirmed', $3, $4);
