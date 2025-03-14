/*
  # Add Driver and Shipping Request Tables

  1. New Tables
    - `drivers`
      - Driver information and status
    - `shipping_requests`
      - Shipping request details
    - `driver_routes`
      - Driver route information
    - `matched_requests`
      - Matches between drivers and shipping requests

  2. Security
    - Enable RLS on all tables
    - Add policies for proper access control
*/

-- Create locations enum
CREATE TYPE location_status AS ENUM ('pending', 'in_progress', 'completed', 'cancelled');

-- Create drivers table
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    current_location TEXT NOT NULL,
    destination TEXT,
    departure_time TIMESTAMPTZ,
    status location_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create shipping requests table
CREATE TABLE IF NOT EXISTS public.shipping_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    pickup_location TEXT NOT NULL,
    delivery_location TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    status location_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create matched requests table
CREATE TABLE IF NOT EXISTS public.matched_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES public.drivers(id) NOT NULL,
    request_id UUID REFERENCES public.shipping_requests(id) NOT NULL,
    status location_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(driver_id, request_id)
);

-- Enable RLS
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matched_requests ENABLE ROW LEVEL SECURITY;

-- Policies for drivers
CREATE POLICY "Users can view their own driver profile"
    ON public.drivers FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own driver profile"
    ON public.drivers FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own driver profile"
    ON public.drivers FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- Policies for shipping requests
CREATE POLICY "Users can view their own shipping requests"
    ON public.shipping_requests FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Drivers can view shipping requests in their route"
    ON public.shipping_requests FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.drivers
            WHERE drivers.user_id = auth.uid()
            AND drivers.destination = shipping_requests.delivery_location
            AND drivers.current_location = shipping_requests.pickup_location
        )
    );

CREATE POLICY "Users can create their own shipping requests"
    ON public.shipping_requests FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own shipping requests"
    ON public.shipping_requests FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- Policies for matched requests
CREATE POLICY "Users can view their matched requests"
    ON public.matched_requests FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.drivers
            WHERE drivers.id = matched_requests.driver_id
            AND drivers.user_id = auth.uid()
        )
        OR
        EXISTS (
            SELECT 1 FROM public.shipping_requests
            WHERE shipping_requests.id = matched_requests.request_id
            AND shipping_requests.user_id = auth.uid()
        )
    );

CREATE POLICY "Drivers can create matched requests"
    ON public.matched_requests FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.drivers
            WHERE drivers.id = matched_requests.driver_id
            AND drivers.user_id = auth.uid()
        )
    );