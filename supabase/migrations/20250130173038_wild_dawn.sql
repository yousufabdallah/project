-- Drop existing view if exists
DROP VIEW IF EXISTS public.shipping_requests_with_users;

-- Create secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
    RETURN (SELECT email FROM auth.users WHERE id = user_id);
END;
$function$;

-- Grant execute permission on the secure function
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;

-- Create view for shipping requests with user information
CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id,
    sr.user_id,
    sr.pickup_location,
    sr.delivery_location,
    sr.description,
    sr.image_url,
    sr.status,
    sr.created_at,
    sr.updated_at,
    auth.get_user_email(sr.user_id) as user_email,
    auth.get_user_email(d.user_id) as driver_email
FROM public.shipping_requests sr
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id;

-- Enable RLS on the view
ALTER VIEW public.shipping_requests_with_users SET (security_invoker = true);

-- Update shipping_requests table policies to allow admin access
DROP POLICY IF EXISTS "Admins can view all shipping requests" ON public.shipping_requests;
CREATE POLICY "Admins can view all shipping requests"
    ON public.shipping_requests
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Grant necessary permissions
GRANT SELECT ON public.shipping_requests_with_users TO authenticated;