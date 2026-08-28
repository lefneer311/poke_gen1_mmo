import * as readline from 'node:readline/promises';
import postgres, { PostgresError } from 'postgres';
import { RegistrationError, registerAccount } from './registration';

interface Options { username: string; email?: string }
const usage = () => 'Usage: npm run account:register -- --username NAME [--email ADDRESS] --password-stdin';

function parseOptions(args: string[]): Options {
  const values = new Map<string, string>();
  let passwordStdin = false;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--password-stdin') passwordStdin = true;
    else if (argument === '--username' || argument === '--email') {
      const value = args[++index];
      if (!value) throw new RegistrationError(`${argument} requires a value.\n${usage()}`);
      values.set(argument, value);
    } else throw new RegistrationError(`Unknown option: ${argument}\n${usage()}`);
  }
  const username = values.get('--username');
  if (!username || !passwordStdin) throw new RegistrationError(usage());
  return { username, email: values.get('--email') };
}

async function readPassword(): Promise<string> {
  if (process.stdin.isTTY) {
    throw new RegistrationError('Pipe the password on standard input; terminal echo is intentionally not supported.');
  }
  const reader = readline.createInterface({ input: process.stdin });
  const password = (await reader.question('')).replace(/[\r\n]+$/, '');
  reader.close();
  return password;
}

async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new RegistrationError('DATABASE_URL is required.');
  const options = parseOptions(process.argv.slice(2));
  const sql = postgres(databaseUrl, { max: 1 });
  try {
    const result = await registerAccount({
      create: (input) => sql.begin(async (transaction) => {
        const [account] = await transaction<{ id: string }[]>`
          INSERT INTO mmo.accounts (username, email) VALUES (${input.username}, ${input.email ?? null}) RETURNING id
        `;
        await transaction`
          INSERT INTO mmo.account_credentials (account_id, password_hash) VALUES (${account.id}, ${input.passwordHash})
        `;
        return account;
      }),
    }, { ...options, password: await readPassword() });
    process.stdout.write(`Created account ${result.username} (${result.id}).\n`);
  } catch (error: unknown) {
    if (error instanceof PostgresError && error.code === '23505') {
      throw new RegistrationError('That username or email address is already registered.');
    }
    throw error;
  } finally {
    await sql.end({ timeout: 5 });
  }
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
