-- Add delivery fee and order value columns to shipping_requests table
ALTER TABLE public.shipping_requests
ADD COLUMN delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
ADD COLUMN order_value DECIMAL(10, 2) NOT NULL DEFAULT 0;

-- Update the view to include the new fields
DROP VIEW IF EXISTS public.shipping_requests_with_users;

CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id,
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