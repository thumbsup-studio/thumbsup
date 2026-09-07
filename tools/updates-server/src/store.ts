import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { ObjectStore } from './types.js';

export class S3ObjectStore implements ObjectStore {
  constructor(
    private readonly bucket: string,
    private readonly client = new S3Client({}),
  ) {}

  async get(key: string): Promise<Uint8Array> {
    const response = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    if (!response.Body) {
      throw new Error(`S3 object has no body: ${key}`);
    }
    return response.Body.transformToByteArray();
  }
}
