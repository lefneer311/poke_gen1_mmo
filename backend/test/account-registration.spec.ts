import { RegistrationError, hashPassword, registerAccount, validateRegistration, verifyPassword } from '../src/account/registration';

describe('account registration', () => {
  it('normalizes identity fields and rejects unsafe input', () => {
    expect(validateRegistration({ username: ' Trainer_1 ', email: 'RED@EXAMPLE.COM ', password: 'correct horse battery' }))
      .toEqual({ username: 'Trainer_1', email: 'red@example.com', password: 'correct horse battery' });
    expect(() => validateRegistration({ username: 'no spaces', password: 'correct horse battery' })).toThrow(RegistrationError);
    expect(() => validateRegistration({ username: 'Red', password: 'short' })).toThrow(RegistrationError);
  });

  it('stores a salted password verifier rather than the password', async () => {
    const encoded = await hashPassword('correct horse battery');
    expect(encoded).not.toContain('correct horse battery');
    await expect(verifyPassword('correct horse battery', encoded)).resolves.toBe(true);
    await expect(verifyPassword('incorrect password', encoded)).resolves.toBe(false);
  });

  it('passes validated data and an encoded verifier to the store', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'account-id' });
    const result = await registerAccount({ create }, {
      username: 'Red_1', email: 'RED@example.com', password: 'correct horse battery',
    });
    expect(result).toEqual({ id: 'account-id', username: 'Red_1' });
    expect(create).toHaveBeenCalledWith(expect.objectContaining({
      username: 'Red_1', email: 'red@example.com', passwordHash: expect.stringMatching(/^scrypt\$/),
    }));
  });
});
