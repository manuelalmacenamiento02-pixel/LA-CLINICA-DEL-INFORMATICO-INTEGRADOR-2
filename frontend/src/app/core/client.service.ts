import { computed, inject, Injectable } from '@angular/core';
import { Client, ClientDraft } from './client.models';
import { ClientDetail } from './sprint-five.models';
import { ApiStore, apiErrorCode } from './api.store';

export type ClientSaveResult = 'success' | 'duplicate-document' | 'duplicate-email' | 'storage-error' | 'not-found';

@Injectable({ providedIn: 'root' })
export class ClientService {
  private readonly store = inject(ApiStore);
  readonly clients = this.store.clients.asReadonly();
  readonly registeredClients = computed(() => this.clients());

  findById(id: string): Client | undefined { return this.clients().find(client => client.id === id); }
  async getDetail(id: string): Promise<ClientDetail> {
    return this.store.write<ClientDetail>('GET', `/clients/${encodeURIComponent(id)}`);
  }
  isDocumentInUse(document: string, excludingId?: string): boolean {
    return this.clients().some(client => client.id !== excludingId &&
      client.documentNumber.trim().toLowerCase() === document.trim().toLowerCase());
  }
  isEmailInUse(email: string, excludingId?: string): boolean {
    return this.clients().some(client => client.id !== excludingId &&
      client.email.trim().toLowerCase() === email.trim().toLowerCase());
  }
  async create(draft: ClientDraft): Promise<ClientSaveResult> { return this.save('POST', '/clients', draft); }
  async update(id: string, draft: ClientDraft): Promise<ClientSaveResult> { return this.save('PUT', '/clients/' + id, draft); }
  private async save(method: string, path: string, draft: ClientDraft): Promise<ClientSaveResult> {
    try {
      const client = await this.store.write<Client>(method, path, draft);
      this.store.clients.update(items => method === 'POST' ? [...items, client] : items.map(item => item.id === client.id ? client : item));
      return 'success';
    } catch (error) {
      const code = apiErrorCode(error);
      return code === 'duplicate-document' || code === 'duplicate-email' || code === 'not-found' ? code : 'storage-error';
    }
  }
  async delete(id: string): Promise<boolean> {
    try {
      await this.store.write('DELETE', '/clients/' + id);
      this.store.clients.update(items => items.filter(item => item.id !== id)); return true;
    } catch { return false; }
  }
}
