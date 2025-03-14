-- Create drivers table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    current_location TEXT NOT NULL,
    destination TEXT NOT NULL,
    departure_time TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create shipping_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.shipping_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    pickup_location TEXT NOT NULL,
    delivery_location TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create matched_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.matched_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) NOT NULL,
    request_id UUID REFERENCES shipping_requests(id) NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
DO $$ 
BEGIN
    ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.shipping_requests ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.matched_requests ENABLE ROW LEVEL SECURITY;
EXCEPTION
    WHEN others THEN NULL;
END $$;

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can create their own driver profile" ON public.drivers;
    DROP POLICY IF EXISTS "Users can view all active drivers" ON public.drivers;
    DROP POLICY IF EXISTS "Users can update their own driver profile" ON public.drivers;
    DROP POLICY IF EXISTS "Users can create shipping requests" ON public.shipping_requests;
    DROP POLICY IF EXISTS "Users can view their own requests and pending requests" ON public.shipping_requests;
    DROP POLICY IF EXISTS "Users can update their own requests" ON public.shipping_requests;
    DROP POLICY IF EXISTS "Drivers can create matches" ON public.matched_requests;
    DROP POLICY IF EXISTS "Users can view their matched requests" ON public.matched_requests;
    DROP POLICY IF EXISTS "Authenticated users can upload shipping images" ON storage.objects;
    DROP POLICY IF EXISTS "Users can view shipping images" ON storage.objects;
END $$;

-- Recreate policies for drivers table
CREATE POLICY "Users can create their own driver profile"
    ON public.drivers
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view all active drivers"
    ON public.drivers
    FOR SELECT
    TO authenticated
    USING (status = 'active');

CREATE POLICY "Users can update their own driver profile"
    ON public.drivers
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Recreate policies for shipping_requests table
CREATE POLICY "Users can create shipping requests"
    ON public.shipping_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own requests and pending requests"
    ON public.shipping_requests
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id 
        OR 
        status = 'pending'
    );

CREATE POLICY "Users can update their own requests"
    ON public.shipping_requests
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Recreate policies for matched_requests table
CREATE POLICY "Drivers can create matches"
    ON public.matched_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.drivers
            WHERE id = matched_requests.driver_id
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can view their matched requests"
    ON public.matched_requests
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.shipping_requests sr
            WHERE sr.id = request_id
            AND sr.user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.drivers d
            WHERE d.id = driver_id
            AND d.user_id = auth.uid()
        )
    );

-- Grant necessary permissions
GRANT ALL ON public.drivers TO authenticated;
GRANT ALL ON public.shipping_requests TO authenticated;
GRANT ALL ON public.matched_requests TO authenticated;

-- Create storage bucket for shipping images if it doesn't exist
DO $$ 
BEGIN
    INSERT INTO storage.buckets (id, name)
    VALUES ('shipping-images', 'shipping-images')
    ON CONFLICT (id) DO NOTHING;
EXCEPTION
    WHEN others THEN NULL;
END $$;

-- Recreate storage policies
CREATE POLICY "Authenticated users can upload shipping images"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'shipping-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view shipping images"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (bucket_id = 'shipping-images');