-- Schema: only tables requested by the assignment.

create table if not exists users (
  id uuid primary key,
  name text not null
);

create table if not exists courses (
  id uuid primary key,
  owner_id uuid not null references users(id),
  name text not null
);

create table if not exists learners (
  user_id uuid not null references users(id),
  course_id uuid not null references courses(id),
  primary key (user_id, course_id)
);

create table if not exists modules (
  id uuid primary key,
  course_id uuid not null references courses(id),
  type text not null check (type in ('info', 'test')),
  content jsonb not null
);

