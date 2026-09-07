import { createSign } from 'node:crypto';
import { GetParameterCommand, SSMClient } from '@aws-sdk/client-ssm';

let cachedPrivateKey: string | null | undefined;

export async function getSigningPrivateKey(): Promise<string | null> {
  if (process.env.SIGNING_PRIVATE_KEY) {
    return process.env.SIGNING_PRIVATE_KEY.replace(/\\n/g, '\n');
  }
  if (cachedPrivateKey !== undefined) {
    return cachedPrivateKey;
  }
  const name = process.env.SIGNING_PRIVATE_KEY_PARAMETER;
  if (!name) {
    return (cachedPrivateKey = null);
  }
  try {
    const result = await new SSMClient({}).send(
      new GetParameterCommand({ Name: name, WithDecryption: true }),
    );
    return (cachedPrivateKey = result.Parameter?.Value ?? null);
  } catch (cause) {
    if ((cause as { name?: string }).name === 'ParameterNotFound') {
      return (cachedPrivateKey = null);
    }
    throw cause;
  }
}

export function signBody(body: string, privateKey: string): string {
  const signer = createSign('RSA-SHA256');
  signer.update(body, 'utf8');
  signer.end();
  return signer.sign(privateKey, 'base64');
}

export function signatureHeader(signature: string, keyId: string): string {
  return `sig="${signature}", keyid="${keyId.replace(/["\\]/g, '')}"`;
}

export function resetSigningKeyCache(): void {
  cachedPrivateKey = undefined;
}
