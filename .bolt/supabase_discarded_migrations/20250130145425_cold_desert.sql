/*
  # Fix admin privileges

  1. Changes
    - Ensure admin user has correct privileges
    - Update user metadata and admin status
    - Add necessary grants and permissions

  2. Security
    - Maintains existing security policies
    - Updates admin privileges securely
*/

-- Function to ensure admin privileges
CREATE OR REPLACE FUNCTION public.ensure_admin_privileges()
RETURNS void AS $$
BEGIN
  -- Update existing admin user
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

  -- Ensure user_roles view is up to date
  DROP VIEW IF EXISTS public.user_roles;
  
  CREATE OR REPLACE VIEW public.user_roles AS
  SELECT 
    id,
    email,
    is_admin,
    raw_user_meta_data->>'is_admin' as meta_is_admin
  FROM auth.users;

  -- Enable RLS on the view
  ALTER VIEW public.user_roles SET (security_invoker = true);

  -- Recreate the policy
  DROP POLICY IF EXISTS "Users can only view their own role" ON public.user_roles;
  
  CREATE POLICY "Users can only view their own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

  -- Grant necessary permissions
  GRANT SELECT ON public.user_roles TO authenticated;
END;
$$ LANGUAGE plpgsql;

-- Execute the function
SELECT ensure_admin_privileges();