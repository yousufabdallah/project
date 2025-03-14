/*
  # Fix user roles permissions final

  1. Changes
    - Create secure function for admin checks
    - Update policies to use secure function
    - Grant necessary permissions
    - Simplify view structure
*/

-- Create secure function for admin checks
CREATE OR REPLACE FUNCTION auth.check_is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = user_id
        AND (raw_user_meta_data->>'is_admin')::boolean = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing policies
DROP POLICY IF EXISTS "Self read access" ON public.user_roles;
DROP POLICY IF EXISTS "Admin read all" ON public.user_roles;
DROP POLICY IF EXISTS "Admin update access" ON public.user_roles;
DROP VIEW IF EXISTS public.user_roles_view;

-- Create new policies using secure function
CREATE POLICY "Self read access"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admin read all"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.check_is_admin(auth.uid()));

CREATE POLICY "Admin update access"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (auth.check_is_admin(auth.uid()))
    WITH CHECK (auth.check_is_admin(auth.uid()));

-- Create simplified view
CREATE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    (SELECT email FROM auth.users WHERE id = ur.id) as email,
    ur.is_admin
FROM public.user_roles ur;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT UPDATE ON public.user_roles TO authenticated;
GRANT EXECUTE ON FUNCTION auth.check_is_admin TO authenticated;

-- Ensure admin user has correct privileges
DO $$ 
DECLARE
    admin_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_id
    FROM auth.users
    WHERE email = 'yousufabdallah2000@gmail.com';

    IF admin_id IS NOT NULL THEN
        -- Update or insert admin role
        INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
        VALUES (admin_id, true, 'true')
        ON CONFLICT (id) DO UPDATE
        SET is_admin = true, meta_is_admin = 'true', updated_at = now();
    END IF;
END $$;