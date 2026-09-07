export type Platform = 'ios' | 'android';

export interface ChannelUpdate {
  updateId: string;
  runtimeVersion: string;
  createdAt: string;
  type?: 'update';
  prNumber?: number;
  branch?: string;
  title?: string;
  commit?: string;
}

export interface ChannelRollback {
  type: 'rollback';
  runtimeVersion: string;
  createdAt: string;
  commitTime: string;
}

export interface ChannelIndex {
  channels: Record<string, Array<ChannelUpdate | ChannelRollback>>;
}

export interface ExpoFileMetadata {
  bundle: string;
  assets: Array<{ path: string; ext: string }>;
}

export interface UpdateMetadata {
  version: number;
  bundler: string;
  fileMetadata: Record<Platform, ExpoFileMetadata>;
  extra?: Record<string, unknown>;
}

export interface ObjectStore {
  get(key: string): Promise<Uint8Array>;
}
