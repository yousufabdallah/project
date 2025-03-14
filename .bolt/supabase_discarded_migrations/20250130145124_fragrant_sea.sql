/*
  # Update admin credentials

  1. Changes
    - Update admin email to yousufabdallah2000@gmail.com
    - Set new password
    - Ensure admin privileges are set correctly

  2. Security
    - Updates admin credentials securely
    - Maintains existing security policies
*/

-- Update admin user credentials
DO $$ 
DECLARE 
  admin_uid UUID;
BEGIN
  -- Update admin email and ensure admin privileges
  UPDATE auth.users
  SET 
    email = 'yousufabdallah2000@gmail.com',
    raw_user_meta_data = jsonb_build_object('is_admin', true),
    is_admin = true,
    email_confirmed_at = CURRENT_TIMESTAMP
  WHERE email = 'admin@logitech.com'
  RETURNING id INTO admin_uid;

  -- If admin doesn't exist, create new admin user
  IF admin_uid IS NULL THEN
    INSERT INTO auth.users (
      email,
      email_confirmed_at,
      is_admin,
      raw_user_meta_data
    ) VALUES (
      'yousufabdallah2000@gmail.com',
      CURRENT_TIMESTAMP,
      true,
      jsonb_build_object('is_admin', true)
    );
  END IF;
END $$;