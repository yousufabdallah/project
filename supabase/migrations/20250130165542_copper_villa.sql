/*
  # Driver Status Management

  1. Changes
    - Add status column to drivers table
    - Create unique index for active drivers
    - Add trigger for managing driver status
    - Clean up existing duplicate active drivers

  2. Security
    - Maintain existing RLS policies
    - No changes to access control
*/

-- Add status column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'drivers' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.drivers ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END $$;

-- First, clean up any existing duplicate active drivers
DO $$
DECLARE
    user_record RECORD;
BEGIN
    -- For each user with multiple active drivers
    FOR user_record IN (
        SELECT DISTINCT user_id
        FROM public.drivers
        WHERE status = 'active'
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) LOOP
        -- Keep only the most recent active driver
        WITH latest_driver AS (
            SELECT id
            FROM public.drivers
            WHERE user_id = user_record.user_id
            AND status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
        )
        UPDATE public.drivers
        SET status = 'inactive'
        WHERE user_id = user_record.user_id
        AND status = 'active'
        AND id NOT IN (SELECT id FROM latest_driver);
    END LOOP;
END $$;

-- Create index for status
CREATE INDEX IF NOT EXISTS idx_drivers_status ON public.drivers(status);

-- Create partial index for active drivers
DROP INDEX IF EXISTS idx_unique_active_driver_per_user;
CREATE UNIQUE INDEX idx_unique_active_driver_per_user 
ON public.drivers (user_id) 
WHERE status = 'active';

-- Create function to handle driver status changes
CREATE OR REPLACE FUNCTION handle_driver_status()
RETURNS TRIGGER AS $$
BEGIN
    -- If the new record is active, deactivate all other drivers for this user
    IF NEW.status = 'active' THEN
        UPDATE public.drivers
        SET status = 'inactive'
        WHERE user_id = NEW.user_id
        AND id != NEW.id
        AND status = 'active';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to manage driver status
DROP TRIGGER IF EXISTS manage_driver_status ON public.drivers;
CREATE TRIGGER manage_driver_status
    BEFORE INSERT OR UPDATE OF status
    ON public.drivers
    FOR EACH ROW
    EXECUTE FUNCTION handle_driver_status();