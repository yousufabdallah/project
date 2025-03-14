/*
  # Fix user roles policies final

  1. Changes
    - Remove all existing policies
    - Create new non-recursive policies
    - Simplify role checking logic
    - Update view structure
*/

-- Drop existing policies and views
DROP POLICY IF EXISTS "Basic read access" ON public.user_roles;
DROP POLICY IF EXISTS "Admin update access" ON public.user_roles;
DROP VIEW IF EXISTS public.user_roles_view;

-- Create new policies with non-recursive logic
CREATE POLICY "Self read access"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admin read all"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
    ));

CREATE POLICY "Admin update access"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
    ))
    WITH CHECK (EXISTS (
        SELECT 1
        FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND (auth.users.raw_user_meta_data->>'is_admin')::boolean = true
    ));

-- Create view for user management
CREATE VIEW public.user_roles_view AS
SELECT 
    u.id,
    u.email,
    COALESCE(ur.is_admin, false) as is_admin
FROM auth.users u
LEFT JOIN public.user_roles ur ON u.id = ur.id;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT UPDATE ON public.user_roles TO authenticated;

-- Ensure admin user has correct privileges
DO $$ 
DECLARE
    admin_id UUID;
BEGIN
    -- Get or create admin user
    SELECT id INTO admin_id
    FROM auth.users
    WHERE email = 'yousufabdallah2000@gmail.com';

    IF admin_id IS NOT NULL THEN
        -- Update auth.users metadata
        UPDATE auth.users
        SET raw_user_meta_data = jsonb_build_object('is_admin', true)
        WHERE id = admin_id;

        -- Update or insert admin role
        INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
        VALUES (admin_id, true, 'true')
        ON CONFLICT (id) DO UPDATE
        SET is_admin = true, meta_is_admin = 'true', updated_at = now();
    END IF;
END $$;