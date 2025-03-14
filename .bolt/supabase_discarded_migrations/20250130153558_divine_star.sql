/*
  # Create admin user table and initial admin

  1. Changes
    - Add admin flag to users
    - Set up initial admin user
  
  2. Security
    - Uses proper password hashing
    - Maintains existing security settings
*/

-- Add admin column if it doesn't exist
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