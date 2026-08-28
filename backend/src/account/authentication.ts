import { createHash, randomBytes } from 'node:crypto';
import { verifyPassword } from './registration';

const GENERIC_FAILURE = 'Username or password is incorrect.';
const DEFAULT_SESSION_LIFETIME_MS = 24 * 60 * 60 * 1000;
// A valid fixed verifier keeps the expensive password check on the unknown-user
// path, reducing the usefulness of response timing for username discovery.
const DUMMY_PASSWORD_HASH = 'scrypt$N=16384,r=8,p=1$AAAAAAAAAAAAAAAAAAAAAA==$yK99vlYIaV57oeErq8gHqx18DxRfiUoHwETrTFUjt5I=';

export interface AuthenticationAccount {
  id: string;
  username: string;
  status: string;
  passwordHash: string;
  lockedUntil?: Date;
}

export interface AuthenticationStore {
  findByUsername(username: string): Promise<AuthenticationAccount | undefined>;
  recordFailure(accountId: string): Promise<void>;
  completeSuccess(input: {
    accountId: string;
    tokenDigest: Buffer;
    expiresAt: Date;
  }): Promise<void>;
}

export class AuthenticationError extends Error {}

export async function authenticateAccount(
  store: AuthenticationStore,
  unchecked: { username: string; password: string },
  options: { now?: Date; sessionLifetimeMs?: number } = {},
): Promise<{ accountId: string; username: string; token: string; expiresAt: Date }> {
  const username = unchecked.username.trim();
  const now = options.now ?? new Date();
  const account = await store.findByUsername(username);
  const validPassword = await verifyPassword(unchecked.password, account?.passwordHash ?? DUMMY_PASSWORD_HASH);
  const usable = account?.status === 'active' && (!account.lockedUntil || account.lockedUntil <= now);

  if (!account || !validPassword || !usable) {
    if (account && !validPassword) await store.recordFailure(account.id);
    throw new AuthenticationError(GENERIC_FAILURE);
  }

  const lifetime = options.sessionLifetimeMs ?? DEFAULT_SESSION_LIFETIME_MS;
  if (!Number.isSafeInteger(lifetime) || lifetime <= 0) throw new Error('Session lifetime must be a positive integer.');
  const expiresAt = new Date(now.getTime() + lifetime);
  const token = randomBytes(32).toString('base64url');
  const tokenDigest = createHash('sha256').update(token, 'utf8').digest();

  // Persistence implementations complete the session insert and failed-attempt
  // reset together, so a partial login cannot be observed.
  await store.completeSuccess({ accountId: account.id, tokenDigest, expiresAt });
  return { accountId: account.id, username: account.username, token, expiresAt };
}
