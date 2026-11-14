import { computed, inject, Injectable } from '@angular/core';
import { Equipment, EquipmentDraft } from './equipment.models';
import { EquipmentServiceHistory } from './sprint-five.models';
import { ApiStore, apiErrorCode } from './api.store';

export type EquipmentSaveResult = 'success' | 'duplicate-serial' | 'storage-error' | 'not-found' | 'client-not-found';

@Injectable({ providedIn: 'root' })
export class EquipmentService {
  private readonly store = inject(ApiStore);
  readonly equipment = this.store.equipment.asReadonly();
  readonly registeredEquipment = computed(() => this.equipment());
  findById(id: string): Equipment | undefined { return this.equipment().find(item => item.id === id); }
  async getHistory(id: string, status = '', from = '', to = ''): Promise<EquipmentServiceHistory> {
    const params = new URLSearchParams();
    if (status) params.set('status', status);
    if (from) params.set('from', from);
    if (to) params.set('to', to);
    const query = params.size > 0 ? `?${params.toString()}` : '';
    return this.store.write<EquipmentServiceHistory>(
      'GET',
      `/equipment/${encodeURIComponent(id)}/history${query}`,
    );
  }
  forClient(id: string): Equipment[] { return this.equipment().filter(item => item.clientId === id); }
  isSerialInUse(serial: string, excludingId?: string): boolean {
    return !!serial.trim() && this.equipment().some(item => item.id !== excludingId &&
      item.serialNumber.trim().toLowerCase() === serial.trim().toLowerCase());
  }
  async create(draft: EquipmentDraft, _clientIds?: ReadonlySet<string>): Promise<EquipmentSaveResult> {
    return this.save('POST', '/equipment', draft);
  }
  async update(id: string, draft: EquipmentDraft, _clientIds?: ReadonlySet<string>): Promise<EquipmentSaveResult> {
    return this.save('PUT', '/equipment/' + id, draft);
  }
  private async save(method: string, path: string, draft: EquipmentDraft): Promise<EquipmentSaveResult> {
    try {
      const item = await this.store.write<Equipment>(method, path, draft);
      this.store.equipment.update(items => method === 'POST' ? [...items, item] : items.map(old => old.id === item.id ? item : old));
      return 'success';
    } catch (error) {
      const code = apiErrorCode(error);
      return code === 'duplicate-serial' || code === 'not-found' || code === 'client-not-found' ? code : 'storage-error';
    }
  }
  async delete(id: string): Promise<boolean> {
    try {
      await this.store.write('DELETE', '/equipment/' + id);
      this.store.equipment.update(items => items.filter(item => item.id !== id)); return true;
    } catch { return false; }
  }
}
