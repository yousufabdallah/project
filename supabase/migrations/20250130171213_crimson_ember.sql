/*
  # Fix driver permissions and policies

  1. Changes
    - Add missing permissions for driver_permissions table
    - Create policy for users to create their own permission request
    - Create policy for users to view their own permission status
    - Create policy for admins to manage all permissions
    
  2. Security
    - Enable RLS
    - Add specific policies for different user roles
*/

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own driver permission" ON public.driver_permissions;
DROP POLICY IF EXISTS "Admins can manage driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "Users can request driver permission" ON public.driver_permissions;

-- Enable RLS
ALTER TABLE public.driver_permissions ENABLE ROW LEVEL SECURITY;

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

-- Create policy for users to view their own permission status
CREATE POLICY "Users can view their own driver permission"
    ON public.driver_permissions
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR 
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Create policy for admins to manage permissions
CREATE POLICY "Admins can manage driver permissions"
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

-- Create view for driver permissions with user information
CREATE OR REPLACE VIEW public.driver_permissions_view AS
SELECT 
    dp.*,
    urv.email as user_email
FROM public.driver_permissions dp
JOIN public.user_roles_view urv ON urv.id = dp.user_id;

-- Grant necessary permissions
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT ALL ON public.driver_permissions TO authenticated;