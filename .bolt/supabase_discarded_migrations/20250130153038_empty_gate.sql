/*
  # Update admin password

  1. Changes
    - Update admin user password to '96327566'
    - Ensure admin privileges are maintained
  
  2. Security
    - Uses proper password hashing
    - Maintains existing security settings
*/

DO $$ 
BEGIN
  -- Update admin user password and ensure admin privileges
  UPDATE auth.users
  SET 
    encrypted_password = crypt('96327566', gen_salt('bf')),
    is_admin = true,
    raw_user_meta_data = jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    ),
    email_confirmed_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
  WHERE email IN ('admin@logitech.com', 'admin@logitech.sa', 'yousufabdallah2000@gmail.com');
END $$;