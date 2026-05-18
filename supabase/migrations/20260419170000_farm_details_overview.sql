
ALTER TABLE public.farm_details
  ADD COLUMN IF NOT EXISTS farm_overview text;

COMMENT ON COLUMN public.farm_details.farm_overview IS
  'Optional long-form description of the farm (region, story, context).';
