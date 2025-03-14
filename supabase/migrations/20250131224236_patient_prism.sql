-- Add is_paid column to shipping_requests table
ALTER TABLE public.shipping_requests
ADD COLUMN is_paid BOOLEAN DEFAULT false;

-- Update existing records
UPDATE public.shipping_requests
SET is_paid = false
WHERE is_paid IS NULL;