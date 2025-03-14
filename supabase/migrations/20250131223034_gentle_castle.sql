-- Drop existing views first
DROP VIEW IF EXISTS public.shipping_requests_with_users CASCADE;
DROP VIEW IF EXISTS public.driver_permissions_view CASCADE;
DROP VIEW IF EXISTS public.user_roles_view CASCADE;
DROP VIEW IF EXISTS public.office_assignments_view CASCADE;

-- Create user_roles_view with explicit column references
CREATE VIEW public.user_roles_view AS
SELECT 
    u.id,
    u.email,
    COALESCE(ur.is_admin, false) as is_admin
FROM auth.users u
LEFT JOIN public.user_roles ur ON ur.id = u.id
WHERE 
    -- User can see their own role
    u.id = auth.uid()
    OR 
    -- Admins can see all roles
    EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE id = auth.uid()
        AND is_admin = true
    );

-- Create driver_permissions_view with explicit column references
CREATE VIEW public.driver_permissions_view AS
SELECT 
    dp.id as permission_id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    u.email as user_email
FROM public.driver_permissions dp
JOIN auth.users u ON u.id = dp.user_id;

-- Create shipping_requests_with_users view with explicit column references
CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id as request_id,
    sr.user_id,
    sr.pickup_location,
    sr.delivery_location,
    sr.description,
    sr.image_url,
    sr.status::text as status,
    sr.delivery_fee,
    sr.order_value,
    sr.created_at,
    sr.updated_at,
    u1.email as user_email,
    u2.email as driver_email
FROM public.shipping_requests sr
JOIN auth.users u1 ON u1.id = sr.user_id
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id
LEFT JOIN auth.users u2 ON u2.id = d.user_id;

-- Create office_assignments_view with explicit column references
CREATE VIEW public.office_assignments_view AS
SELECT 
    oa.id as assignment_id,
    oa.region_id,
    oa.user_id,
    r.name as region_name,
    u.email as user_email,
    oa.created_at,
    oa.updated_at
FROM public.office_assignments oa
JOIN public.regions r ON r.id = oa.region_id
JOIN auth.users u ON u.id = oa.user_id;

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT SELECT ON public.shipping_requests_with_users TO authenticated;
GRANT SELECT ON public.office_assignments_view TO authenticated;