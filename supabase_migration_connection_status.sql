-- ============================================================
-- PERISAI — SQL Migration untuk Status Koneksi
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- 1. Ubah default connection_status ke 'offline_manual'
ALTER TABLE children ALTER COLUMN connection_status SET DEFAULT 'offline_manual';

-- 2. Reset SEMUA anak yang masih 'online' padahal belum pernah connect
UPDATE children SET connection_status = 'offline_manual' WHERE connection_status = 'online';

-- 3. Buat RPC function supaya HP anak bisa update status TANPA auth session
CREATE OR REPLACE FUNCTION update_child_connection(
  p_child_id UUID,
  p_status TEXT,
  p_last_seen TIMESTAMPTZ DEFAULT NOW()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER  -- bypass RLS
AS $$
BEGIN
  UPDATE children
  SET connection_status = p_status,
      last_seen = p_last_seen
  WHERE id = p_child_id;
END;
$$;

-- 4. Tambahkan RLS policy agar semua orang bisa panggil RPC
-- (SECURITY DEFINER sudah handle ini, tapi just in case)
GRANT EXECUTE ON FUNCTION update_child_connection TO anon, authenticated;
