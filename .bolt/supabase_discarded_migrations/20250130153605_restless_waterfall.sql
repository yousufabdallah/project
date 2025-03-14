/*
  # Update user roles and admin settings

  1. Changes
    - Update user roles view
    - Set admin metadata
  
  2. Security
    - Maintain RLS policies
*/

-- Update or create the view
CREATE OR REPLACE VIEW public.user_roles AS
SELECT 
  u.id,
  u.email,
  u.is_admin,
  u.raw_user_meta_data->>'is_admin' as meta_is_admin
FROM auth.users u;

-- Update admin user metadata
UPDATE auth.users
SET 
  is_admin = true,
  raw_user_meta_data = 
    CASE 
      WHEN raw_user_meta_data IS NULL THEN 
        jsonb_build_object('is_admin', true)
      ELSE 
        raw_user_meta_data || jsonb_build_object('is_admin', true)
    END
WHERE email = 'yousufabdallah2000@gmail.com';