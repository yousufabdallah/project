/*
  # Fix user roles permissions

  1. Changes
    - Replace materialized view with regular view
    - Add proper permissions for authenticated users
    - Ensure proper RLS policies
*/

-- Drop existing materialized view and related objects
DROP MATERIALIZED VIEW IF EXISTS public.user_roles_view;
DROP TRIGGER IF EXISTS refresh_user_roles_view_trigger ON public.user_roles;
DROP FUNCTION IF EXISTS refresh_user_roles_view();

-- Create regular view instead
CREATE OR REPLACE VIEW public.user_roles_view AS
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

-- Create policy for the view
CREATE POLICY "Admins can view all roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Create policy for regular users to view their own role
CREATE POLICY "Users can view their own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);