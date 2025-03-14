-- Drop existing views and functions first
DROP VIEW IF EXISTS public.shipping_requests_with_users CASCADE;
DROP VIEW IF EXISTS public.driver_permissions_view CASCADE;
DROP VIEW IF EXISTS public.user_roles_view CASCADE;
DROP VIEW IF EXISTS public.office_assignments_view CASCADE;
DROP FUNCTION IF EXISTS auth.get_users_list();

-- Create a secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT email FROM auth.users WHERE id = user_id;
$$;

-- Create a secure function to get users list for admins
CREATE FUNCTION auth.get_users_list()
RETURNS TABLE (
    id UUID,
    email TEXT,
    is_admin BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Check if the current user is an admin
    IF EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE id = auth.uid() 
        AND is_admin = true
    ) THEN
        RETURN QUERY
        SELECT 
            u.id,
            u.email,
            COALESCE(ur.is_admin, false)
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.id = u.id;
    ELSE
        -- Return only the current user's information
        RETURN QUERY
        SELECT 
            u.id,
            u.email,
            COALESCE(ur.is_admin, false)
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.id = u.id
        WHERE u.id = auth.uid();
    END IF;
END;
$$;

-- Create user_roles_view using the secure function
CREATE VIEW public.user_roles_view AS
SELECT 
    id,
    email,
    is_admin
FROM auth.get_users_list();

-- Create driver_permissions_view
CREATE VIEW public.driver_permissions_view AS
SELECT 
    dp.id as permission_id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    auth.get_user_email(dp.user_id) as user_email
FROM public.driver_permissions dp;

-- Create shipping_requests_with_users view
CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id as request_id,
    sr.user_id,
    sr.pickup_location,
    sr.delivery_location,
    sr.description,
    sr.image_url,
    sr.status::text,
    sr.delivery_fee,
    sr.order_value,
    sr.created_at,
    sr.updated_at,
    auth.get_user_email(sr.user_id) as user_email,
    auth.get_user_email(d.user_id) as driver_email
FROM public.shipping_requests sr
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id;

-- Create office_assignments_view
CREATE VIEW public.office_assignments_view AS
SELECT 
    oa.id as assignment_id,
    oa.region_id,
    oa.user_id,
    r.name as region_name,
    auth.get_user_email(oa.user_id) as user_email,
    oa.created_at,
    oa.updated_at
FROM public.office_assignments oa
JOIN public.regions r ON r.id = oa.region_id;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_users_list TO authenticated;
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT SELECT ON public.shipping_requests_with_users TO authenticated;
GRANT SELECT ON public.office_assignments_view TO authenticated;