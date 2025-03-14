/*
  # Fix user roles and permissions

  1. Changes
    - Update policies to use direct checks instead of function
    - Create secure functions for user management
    - Fix view permissions
    - Update admin privileges
*/

-- Drop existing view first
DROP VIEW IF EXISTS public.user_roles_view;

-- Create secure functions
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT email 
        FROM auth.users 
        WHERE id = user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update policies to use direct checks
DROP POLICY IF EXISTS "Self read access" ON public.user_roles;
DROP POLICY IF EXISTS "Admin read all" ON public.user_roles;
DROP POLICY IF EXISTS "Admin update access" ON public.user_roles;

CREATE POLICY "Self read access"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admin read all"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

CREATE POLICY "Admin update access"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

-- Create secure view
CREATE OR REPLACE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    auth.get_user_email(ur.id) as email,
    ur.is_admin
FROM public.user_roles ur
WHERE 
    -- User can see their own role
    auth.uid() = ur.id
    OR 
    -- Admins can see all roles
    EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
    );

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT UPDATE ON public.user_roles TO authenticated;

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