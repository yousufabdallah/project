-- Create view for shipping requests with user information
CREATE OR REPLACE VIEW public.shipping_requests_with_users AS
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
    sender.email as user_email,
    driver.email as driver_email
FROM public.shipping_requests sr
JOIN auth.users sender ON sender.id = sr.user_id
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id
LEFT JOIN auth.users driver ON driver.id = d.user_id;

-- Enable RLS on the view
ALTER VIEW public.shipping_requests_with_users SET (security_invoker = true);

-- Update shipping_requests table policies to allow admin access
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