create schema rideXpress;

SET search_path TO rideXpress, public;

SHOW search_path;

create table users (
  user_id bigint primary key generated always as identity,
  name text not null,
  email text unique not null,
  role text check (role in ('passenger', 'driver', 'admin')) not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create table drivers (
  driver_id bigint primary key generated always as identity,
  user_id bigint references users (user_id),
  license_number text unique not null,
  average_rating numeric(3, 2),
  total_rides int default 0
);

create table cars (
  car_id bigint primary key generated always as identity,
  driver_id bigint references drivers (driver_id),
  make text not null,
  model text not null,
  year int not null,
  license_plate text unique not null,
  color text
);

create table rides (
  ride_id bigint primary key generated always as identity,
  user_id bigint references users (user_id),
  driver_id bigint references drivers (driver_id),
  status text check (status in ('started', 'completed', 'canceled')) not null,
  start_location text not null,
  end_location text not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create table feedback (
  feedback_id bigint primary key generated always as identity,
  ride_id bigint references rides (ride_id),
  user_id bigint references users (user_id),
  rating int check (rating between 1 and 5),
  comment text
);

create table locations (
  location_id bigint primary key generated always as identity,
  driver_id bigint references drivers (driver_id),
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  "timestamp" timestamp with time zone default now()
);

create index idx_ride_user on rides using btree (user_id);

create index idx_ride_driver on rides using btree (driver_id);

create index idx_feedback_ride on feedback using btree (ride_id);

create index idx_feedback_user on feedback using btree (user_id);

create index idx_location_driver on locations using btree (driver_id);