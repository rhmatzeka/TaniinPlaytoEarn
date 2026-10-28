CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  privy_user_id text NOT NULL,
  wallet text NOT NULL,
  login_method text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS sessions_expires_idx ON sessions (expires_at);

CREATE TABLE IF NOT EXISTS rate_limits (
  key text PRIMARY KEY,
  count integer NOT NULL,
  reset_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS idempotency (
  scoped_key text PRIMARY KEY,
  status text NOT NULL,
  response jsonb,
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS players (
  wallet text PRIMARY KEY,
  privy_user_id text,
  state jsonb NOT NULL,
  imported_guest boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_usage (
  wallet text NOT NULL,
  day date NOT NULL,
  tani_minted numeric NOT NULL DEFAULT 0,
  eth_paid_wei numeric NOT NULL DEFAULT 0,
  PRIMARY KEY (wallet, day)
);

CREATE TABLE IF NOT EXISTS funding_txs (
  tx_hash text PRIMARY KEY,
  wallet text NOT NULL,
  used_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_log (
  id bigserial PRIMARY KEY,
  wallet text NOT NULL,
  action text NOT NULL,
  amount numeric,
  plot_id integer,
  tx_hashes jsonb,
  result text NOT NULL,
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS audit_log_wallet_idx ON audit_log (wallet, created_at DESC);

CREATE TABLE IF NOT EXISTS auth_codes (
  code_hash text PRIMARY KEY,
  challenge text NOT NULL,
  privy_user_id text NOT NULL,
  wallet text NOT NULL,
  login_method text NOT NULL DEFAULT '',
  expires_at timestamptz NOT NULL
);

-- A Privy user can change wallets; one player row per wallet, not per user.
ALTER TABLE players DROP CONSTRAINT IF EXISTS players_privy_user_id_key;
CREATE INDEX IF NOT EXISTS players_privy_user_idx ON players (privy_user_id);
