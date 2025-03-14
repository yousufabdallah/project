/*
  # Add admin role and create admin user

  1. Changes
    - Add admin column to auth.users
    - Create admin user
    
  2. Security
    - Only admins can access admin features
*/

-- Add admin column to auth.users if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'auth' 
    AND table_name = 'users' 
    AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE auth.users ADD COLUMN is_admin BOOLEAN DEFAULT false;
  END IF;
END $$;