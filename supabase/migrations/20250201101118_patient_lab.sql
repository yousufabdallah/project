-- Add delivery_type column to shipping_requests table
ALTER TABLE public.shipping_requests
ADD COLUMN delivery_type TEXT CHECK (delivery_type IN ('office', 'home')) DEFAULT 'office';

-- Add sender and recipient information columns
ALTER TABLE public.shipping_requests
ADD COLUMN sender_name TEXT NOT NULL DEFAULT '',
ADD COLUMN sender_phone TEXT NOT NULL DEFAULT '',
ADD COLUMN recipient_name TEXT NOT NULL DEFAULT '',
ADD COLUMN recipient_phone TEXT NOT NULL DEFAULT '';

-- Update the view to include new columns
DROP VIEW IF EXISTS public.shipping_requests_with_users;

CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id as request_id,
    sr.user_id,
    sr.sender_name,
    sr.sender_phone,
    sr.recipient_name,
    sr.recipient_phone,
    sr.pickup_location,
    sr.delivery_location,
    sr.delivery_type,
    sr.description,
    sr.image_url,
    sr.status::text as status,
    sr.delivery_fee,
    sr.order_value,
    sr.is_paid,
    sr.office_id,
    sr.created_at,
    sr.updated_at,
    u1.email as user_email,
    u2.email as driver_email,
    r.name as office_region
FROM public.shipping_requests sr
JOIN auth.users u1 ON u1.id = sr.user_id
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id
LEFT JOIN auth.users u2 ON u2.id = d.user_id
LEFT JOIN public.office_assignments oa ON oa.id = sr.office_id
LEFT JOIN public.regions r ON r.id = oa.region_id;