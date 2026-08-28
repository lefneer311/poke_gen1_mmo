import { randomBytes, scrypt as nodeScrypt, timingSafeEqual } from 'node:crypto';
const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,32}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const SCRYPT_COST = 16384;

function scrypt(password: string, salt: Buffer, length: number, options: { N: number; r: number; p: number }): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    nodeScrypt(password, salt, length, options, (error, derived) => error ? reject(error) : resolve(derived));
  });
}

export interface RegistrationInput { username: string; email?: string; password: string }
export interface AccountRegistrationStore {
  create(input: { username: string; email?: string; passwordHash: string }): Promise<{ id: string }>;
}
export class RegistrationError extends Error {}

export function validateRegistration(input: RegistrationInput): RegistrationInput {
  const username = input.username.trim();
  const email = input.email?.trim().toLowerCase() || undefined;
  if (!USERNAME_PATTERN.test(username)) {
    throw new RegistrationError('Username must be 3-32 letters, numbers, or underscores.');
  }
  if (email && (email.length > 254 || !EMAIL_PATTERN.test(email))) {
    throw new RegistrationError('Email address is not valid.');
  }
  const passwordBytes = Buffer.byteLength(input.password, 'utf8');
  if (passwordBytes < 12 || passwordBytes > 128) {
    throw new RegistrationError('Password must be between 12 and 128 UTF-8 bytes.');
  }
  return { username, email, password: input.password };
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const derived = await scrypt(password, salt, 32, { N: SCRYPT_COST, r: 8, p: 1 }) as Buffer;
  return `scrypt$N=${SCRYPT_COST},r=8,p=1$${salt.toString('base64')}$${derived.toString('base64')}`;
}

export async function verifyPassword(password: string, encoded: string): Promise<boolean> {
  const match = /^scrypt\$N=(\d+),r=(\d+),p=(\d+)\$([^$]+)\$([^$]+)$/.exec(encoded);
  if (!match) return false;
  const [, n, r, p, saltValue, hashValue] = match;
  const expected = Buffer.from(hashValue, 'base64');
  const actual = await scrypt(password, Buffer.from(saltValue, 'base64'), expected.length, {
    N: Number(n), r: Number(r), p: Number(p),
  }) as Buffer;
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export async function registerAccount(store: AccountRegistrationStore, unchecked: RegistrationInput) {
  const input = validateRegistration(unchecked);
  const account = await store.create({
    username: input.username,
    email: input.email,
    passwordHash: await hashPassword(input.password),
  });
  return { id: account.id, username: input.username };
}
