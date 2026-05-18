ALTER TABLE messages
ADD COLUMN IF NOT EXISTS post_id uuid REFERENCES posts (id);
