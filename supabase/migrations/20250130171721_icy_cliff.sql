/*
  # Fix driver permissions view and policies

  1. Changes
    - Drop and recreate driver permissions view
    - Update policies for proper access control
    - Fix join with user_roles_view
    
  2. Security
    - Maintain RLS
    - Ensure proper access control
*/

-- Drop existing view if exists
DROP VIEW IF EXISTS public.driver_permissions_view;

-- Create view for driver permissions with user information
CREATE OR REPLACE VIEW public.driver_permissions_view AS
SELECT 
    dp.id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    urv.email as user_email
FROM public.driver_permissions dp
JOIN public.user_roles_view urv ON urv.id = dp.user_id;

-- Enable RLS on the view
ALTER VIEW public.driver_permissions_view SET (security_invoker = true);

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own driver permission" ON public.driver_permissions;
DROP POLICY IF EXISTS "Admins can manage driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "Users can request driver permission" ON public.driver_permissions;

-- Create policy for users to request driver permission
CREATE POLICY "Users can request driver permission"
    ON public.driver_permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND NOT EXISTS (
            SELECT 1 FROM public.driver_permissions
            WHERE user_id = auth.uid()
        )
    );

-- Create policy for viewing driver permissions
CREATE POLICY "View driver permissions"
    ON public.driver_permissions
    FOR SELECT
    TO authenticated
    USING (
        -- Users can view their own permissions
        auth.uid() = user_id
        OR 
        -- Admins can view all permissions
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Create policy for updating driver permissions
CREATE POLICY "Update driver permissions"
    ON public.driver_permissions
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Grant necessary permissions
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT ALL ON public.driver_permissions TO authenticated;