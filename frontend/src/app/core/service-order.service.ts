import { inject, Injectable, signal } from '@angular/core';
import { ApiStore } from './api.store';
import {
  OrderTechnician,
  Prediagnosis,
  PrediagnosisResult,
  ServiceOrder,
  ServiceOrderDraft,
  TechnicalAttention,
  TechnicalAttentionDraft,
} from './service-order.models';
import { PublicTrackingResult, TrackingDetail, TrackingOrder } from './sprint-five.models';

@Injectable({ providedIn: 'root' })
export class ServiceOrderService {
  private readonly store = inject(ApiStore);
  private readonly orderState = signal<ServiceOrder[]>([]);
  private readonly assignedState = signal<ServiceOrder[]>([]);
  readonly orders = this.orderState.asReadonly();
  readonly assignedOrders = this.assignedState.asReadonly();
  readonly technicians = signal<OrderTechnician[]>([]);
  async load(search = '', status = ''): Promise<void> {
    const params = new URLSearchParams();
    if (search.trim()) params.set('q', search.trim());
    if (status) params.set('status', status);
    const serialized = params.toString();
    const query = serialized ? `?${serialized}` : '';
    this.orderState.set(await this.store.write<ServiceOrder[]>('GET', `/orders${query}`));
  }

  async loadAssigned(): Promise<void> {
    this.assignedState.set(await this.store.write<ServiceOrder[]>('GET', '/orders/mine'));
  }

  async getTrackingOrders(search = '', status = ''): Promise<TrackingOrder[]> {
    const params = new URLSearchParams();
    if (search.trim()) params.set('q', search.trim());
    if (status) params.set('status', status);
    const query = params.size > 0 ? `?${params.toString()}` : '';
    return this.store.write<TrackingOrder[]>('GET', `/tracking/orders${query}`);
  }

  async getTrackingDetail(id: string): Promise<TrackingDetail> {
    return this.store.write<TrackingDetail>('GET', `/tracking/orders/${encodeURIComponent(id)}`);
  }

  async getPublicTracking(code: string, phone: string): Promise<PublicTrackingResult> {
    return this.store.write<PublicTrackingResult>('POST', '/public/tracking', { code, phone });
  }

  async loadTechnicians(): Promise<void> {
    this.technicians.set(await this.store.write<OrderTechnician[]>('GET', '/orders/technicians'));
  }

  async get(id: string): Promise<ServiceOrder> {
    return this.store.write<ServiceOrder>('GET', `/orders/${encodeURIComponent(id)}`);
  }

  async create(draft: ServiceOrderDraft): Promise<ServiceOrder> {
    return this.store.write<ServiceOrder>('POST', '/orders', draft);
  }

  async update(id: string, draft: ServiceOrderDraft): Promise<ServiceOrder> {
    return this.store.write<ServiceOrder>('PUT', `/orders/${encodeURIComponent(id)}`, draft);
  }

  async assign(id: string, technicianId: string, notes: string): Promise<ServiceOrder> {
    return this.store.write<ServiceOrder>(
      'POST',
      `/orders/${encodeURIComponent(id)}/assignment`,
      { technicianId, notes },
    );
  }

  async changeStatus(id: string, status: string, reason = ''): Promise<ServiceOrder> {
    return this.store.write<ServiceOrder>(
      'PATCH',
      `/orders/${encodeURIComponent(id)}/status`,
      { status, reason },
    );
  }

  async getAttention(orderId: string): Promise<TechnicalAttention | null> {
    const result = await this.store.write<TechnicalAttention | Record<string, never>>(
      'GET',
      `/orders/${encodeURIComponent(orderId)}/attention`,
    );
    return 'id' in result ? result as TechnicalAttention : null;
  }

  async saveAttention(orderId: string, draft: TechnicalAttentionDraft): Promise<TechnicalAttention> {
    return this.store.write<TechnicalAttention>(
      'PUT',
      `/orders/${encodeURIComponent(orderId)}/attention`,
      draft,
    );
  }

  async finalizeOrder(orderId: string): Promise<void> {
    await this.store.write('POST', `/orders/${encodeURIComponent(orderId)}/finalize`);
  }

  async getPrediagnoses(orderId: string): Promise<Prediagnosis[]> {
    return this.store.write<Prediagnosis[]>('GET', `/orders/${encodeURIComponent(orderId)}/prediagnoses`);
  }

  async generatePrediagnosis(
    orderId: string,
    additionalSymptoms: string,
    observations: string,
  ): Promise<Prediagnosis> {
    return this.store.write<Prediagnosis>(
      'POST',
      `/orders/${encodeURIComponent(orderId)}/prediagnoses`,
      { additionalSymptoms, observations },
    );
  }

  async validatePrediagnosis(
    id: string,
    decision: 'ACEPTADO' | 'MODIFICADO' | 'DESCARTADO',
    observations: string,
    modifiedResult?: PrediagnosisResult,
  ): Promise<void> {
    await this.store.write(
      'PATCH',
      `/prediagnoses/${encodeURIComponent(id)}/validation`,
      { decision, observations, modifiedResult: modifiedResult ?? null },
    );
  }
}
