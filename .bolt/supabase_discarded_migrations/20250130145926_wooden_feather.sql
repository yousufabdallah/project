/*
  # Ensure Admin Privileges

  1. Changes
    - Ensures admin privileges for specific user
    - Updates user metadata and admin status
    - Adds necessary policies and permissions

  2. Security
    - Updates admin privileges in auth.users table
    - Ensures proper metadata is set
*/

-- Ensure admin privileges for specific user
DO $$ 
BEGIN
  -- Update existing user to have admin privileges
  UPDATE auth.users
  SET 
    is_admin = true,
    raw_user_meta_data = jsonb_build_object('is_admin', true)
  WHERE email = 'yousufabdallah2000@gmail.com';

  -- If user doesn't exist, create them with admin privileges
  IF NOT FOUND THEN
    INSERT INTO auth.users (
      email,
      is_admin,
      raw_user_meta_data,
      email_confirmed_at
    ) VALUES (
      'yousufabdallah2000@gmail.com',
      true,
      jsonb_build_object('is_admin', true),
      CURRENT_TIMESTAMP
    );
  END IF;
END $$;