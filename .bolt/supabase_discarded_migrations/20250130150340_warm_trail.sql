/*
  # Create New Admin Account

  1. Changes
    - Creates a new admin user with full privileges
    - Sets up proper metadata and permissions
    - Ensures admin status is properly set

  2. Security
    - Sets admin privileges in auth.users table
    - Configures proper metadata
*/

-- Create new admin user with full privileges
DO $$ 
BEGIN
  -- Create new admin user
  INSERT INTO auth.users (
    email,
    password,
    email_confirmed_at,
    is_admin,
    raw_user_meta_data
  )
  VALUES (
    'admin@logitech.sa',
    crypt('Admin123!', gen_salt('bf')),
    CURRENT_TIMESTAMP,
    true,
    jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    )
  )
  ON CONFLICT (email) 
  DO UPDATE SET
    is_admin = true,
    raw_user_meta_data = jsonb_build_object(
      'is_admin', true,
      'role', 'admin'
    );

  -- Ensure user_roles view is updated
  REFRESH MATERIALIZED VIEW IF EXISTS public.user_roles;
END $$;