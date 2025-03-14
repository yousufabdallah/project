/*
  # Create admin user

  1. Changes
    - Create admin user with proper authentication
    - Set admin privileges in both is_admin column and user metadata
    - Ensure email confirmation is set
  
  2. Security
    - Uses proper authentication fields
    - Sets appropriate role and permissions
*/

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
  SELECT
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@logitech.com',
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
  WHERE NOT EXISTS (
    SELECT 1 FROM auth.users WHERE email = 'admin@logitech.com'
  );

  -- Update existing admin if it exists
  UPDATE auth.users
  SET 
    is_admin = true,
    raw_user_meta_data = jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    ),
    email_confirmed_at = CURRENT_TIMESTAMP
  WHERE email = 'admin@logitech.com';
END $$;