/*
  # Fix user roles permissions

  1. Changes
    - Simplify user roles access
    - Add direct table access for authenticated users
    - Fix view permissions
    - Update policies to be more permissive
*/

-- Drop existing view and policies
DROP VIEW IF EXISTS public.user_roles_view;
DROP POLICY IF EXISTS "Self read access" ON public.user_roles;
DROP POLICY IF EXISTS "Admin read all" ON public.user_roles;
DROP POLICY IF EXISTS "Admin update access" ON public.user_roles;

-- Create simplified view without joins
CREATE VIEW public.user_roles_view AS
SELECT 
    id,
    is_admin
FROM public.user_roles;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Create simplified policies
CREATE POLICY "Anyone can read user_roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can update user_roles"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.user_roles
            WHERE id = auth.uid()
            AND is_admin = true
        )
    );

-- Grant necessary permissions
GRANT ALL ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles_view TO authenticated;

-- Ensure admin user exists
DO $$ 
DECLARE
    admin_email TEXT := 'yousufabdallah2000@gmail.com';
    admin_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_id
    FROM auth.users
    WHERE email = admin_email;

    IF admin_id IS NOT NULL THEN
        -- Insert or update admin role
        INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
        VALUES (admin_id, true, 'true')
        ON CONFLICT (id) DO UPDATE
        SET is_admin = true, meta_is_admin = 'true', updated_at = now();
    END IF;
END $$;