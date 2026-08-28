import { createHash } from 'node:crypto';
import { authenticateAccount, AuthenticationError, AuthenticationStore } from '../src/account/authentication';
import { hashPassword, verifyPassword } from '../src/account/registration';

function store(overrides: Partial<AuthenticationStore> = {}): AuthenticationStore {
  return {
    findByUsername: jest.fn().mockResolvedValue(undefined),
    recordFailure: jest.fn().mockResolvedValue(undefined),
    completeSuccess: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

describe('account authentication', () => {
  it('returns an opaque token but stores only its digest', async () => {
    const passwordHash = await hashPassword('correct horse battery');
    const authStore = store({ findByUsername: jest.fn().mockResolvedValue({
      id: 'account-id', username: 'Red', status: 'active', passwordHash,
    }) });
    const now = new Date('2026-08-28T12:00:00Z');

    const result = await authenticateAccount(authStore, {
      username: ' Red ', password: 'correct horse battery',
    }, { now, sessionLifetimeMs: 60_000 });

    expect(result).toMatchObject({ accountId: 'account-id', username: 'Red', expiresAt: new Date('2026-08-28T12:01:00Z') });
    expect(result.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(authStore.completeSuccess).toHaveBeenCalledWith({
      accountId: 'account-id',
      tokenDigest: createHash('sha256').update(result.token).digest(),
      expiresAt: result.expiresAt,
    });
  });

  it('uses one generic failure for unknown, invalid, locked, and inactive accounts', async () => {
    const passwordHash = await hashPassword('correct horse battery');
    for (const account of [
      undefined,
      { id: '1', username: 'Red', status: 'active', passwordHash },
      { id: '1', username: 'Red', status: 'locked', passwordHash },
      { id: '1', username: 'Red', status: 'active', passwordHash, lockedUntil: new Date('2099-01-01') },
    ]) {
      const authStore = store({ findByUsername: jest.fn().mockResolvedValue(account) });
      const password = account?.status === 'active' && !account.lockedUntil ? 'wrong password' : 'correct horse battery';
      await expect(authenticateAccount(authStore, { username: 'Red', password }))
        .rejects.toEqual(new AuthenticationError('Username or password is incorrect.'));
      expect(authStore.completeSuccess).not.toHaveBeenCalled();
    }
  });

  it('rejects tampered scrypt parameters without attempting an unsafe allocation', async () => {
    const encoded = await hashPassword('correct horse battery');
    await expect(verifyPassword('correct horse battery', encoded.replace('N=16384', 'N=1073741824'))).resolves.toBe(false);
    await expect(verifyPassword('correct horse battery', `${encoded}garbage`)).resolves.toBe(false);
  });
});
