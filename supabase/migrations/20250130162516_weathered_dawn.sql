/*
  # Fix user roles recursion

  1. Changes
    - Simplify user roles policies to prevent recursion
    - Update view permissions
    - Add proper update policies
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can view their own role" ON public.user_roles;

-- Create new simplified policies
CREATE POLICY "Basic read access"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        -- Allow users to read their own role
        auth.uid() = id
        OR
        -- Allow users marked as admin in their own role to read all roles
        (SELECT is_admin FROM public.user_roles WHERE id = auth.uid())
    );

-- Policy for updating roles (admin only)
CREATE POLICY "Admin update access"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (
        -- User must be marked as admin in their own role
        (SELECT is_admin FROM public.user_roles WHERE id = auth.uid())
    )
    WITH CHECK (
        -- User must be marked as admin in their own role
        (SELECT is_admin FROM public.user_roles WHERE id = auth.uid())
    );

-- Drop and recreate the view with simplified access
DROP VIEW IF EXISTS public.user_roles_view;

CREATE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    u.email,
    ur.is_admin
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.id;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT UPDATE ON public.user_roles TO authenticated;

-- Ensure admin user exists with correct privileges
DO $$ 
DECLARE
    admin_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_id
    FROM auth.users
    WHERE email = 'yousufabdallah2000@gmail.com';

    -- Update or insert admin role
    IF admin_id IS NOT NULL THEN
        INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
        VALUES (admin_id, true, 'true')
        ON CONFLICT (id) DO UPDATE
        SET is_admin = true, meta_is_admin = 'true', updated_at = now();
    END IF;
END $$;