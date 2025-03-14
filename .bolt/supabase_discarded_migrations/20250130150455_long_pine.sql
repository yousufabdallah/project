/*
  # Fix Admin Account Creation

  1. Changes
    - Creates a new admin user with proper authentication
    - Sets up admin privileges correctly
    - Uses proper Supabase auth functions
*/

-- Create new admin user with proper authentication
DO $$ 
BEGIN
  -- Create new admin user using auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    is_admin,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@logitech.sa',
    -- Using a pre-hashed password for 'Admin123!'
    '$2a$10$5J5Xk7zXZLXA.8SI8Mq.gu.F8N5LkARGhVgqJcMkrWsIuVdlKpHAy',
    CURRENT_TIMESTAMP,
    true,
    jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    ),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (email) 
  DO UPDATE SET
    is_admin = true,
    raw_user_meta_data = jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    ),
    encrypted_password = '$2a$10$5J5Xk7zXZLXA.8SI8Mq.gu.F8N5LkARGhVgqJcMkrWsIuVdlKpHAy';
END $$;