/*
  # Fix permissions and queries

  1. Create secure functions for user access
  2. Update views to use secure functions
  3. Grant necessary permissions
*/

-- Create secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN (
        SELECT email 
        FROM auth.users 
        WHERE id = user_id
    );
END;
$$;

-- Create secure function to check if user is admin
CREATE OR REPLACE FUNCTION auth.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE id = user_id
        AND (raw_user_meta_data->>'is_admin')::boolean = true
    );
END;
$$;

-- Drop existing views
DROP VIEW IF EXISTS public.driver_permissions_view;
DROP VIEW IF EXISTS public.office_assignments_view;

-- Recreate driver_permissions_view using secure function
CREATE VIEW public.driver_permissions_view AS
SELECT 
    dp.id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    auth.get_user_email(dp.user_id) as user_email
FROM public.driver_permissions dp
WHERE 
    -- Users can see their own permissions
    auth.uid() = dp.user_id
    OR 
    -- Admins can see all permissions
    auth.is_admin(auth.uid());

-- Recreate office_assignments_view using secure function
CREATE VIEW public.office_assignments_view AS
SELECT 
    oa.id,
    oa.region_id,
    oa.user_id,
    r.name as region_name,
    auth.get_user_email(oa.user_id) as user_email,
    oa.created_at,
    oa.updated_at
FROM public.office_assignments oa
JOIN public.regions r ON r.id = oa.region_id
WHERE 
    -- Users can see their own assignments
    auth.uid() = oa.user_id
    OR 
    -- Admins can see all assignments
    auth.is_admin(auth.uid());

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION auth.is_admin TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT SELECT ON public.office_assignments_view TO authenticated;