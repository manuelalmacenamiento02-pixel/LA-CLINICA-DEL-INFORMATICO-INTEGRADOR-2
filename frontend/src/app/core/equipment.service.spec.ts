import { TestBed } from '@angular/core/testing';
import { HttpTestingController } from '@angular/common/http/testing';
import { EquipmentService } from './equipment.service';
import { ApiStore } from './api.store';
import { configureApi } from './api-test.helpers';

const draft = { clientId: 'client-1', type: 'Laptop' as const, brand: 'Lenovo', model: 'E14', serialNumber: 'SN-1', characteristics: '', accessories: '', observations: '' };
describe('Equipment API persistence', () => {
  let http: HttpTestingController; let service: EquipmentService;
  beforeEach(() => { http = configureApi(); service = TestBed.inject(EquipmentService); });
  afterEach(() => http.verify());
  it('persists the selected owner on the server', async () => {
    const task = service.create(draft);
    const request = http.expectOne('/api/equipment'); expect(request.request.body.clientId).toBe('client-1');
    request.flush({ ...draft, id: 'equipment-1' });
    expect(await task).toBe('success'); expect(service.forClient('client-1').length).toBe(1);
  });
  it('does not add equipment when its client is rejected', async () => {
    const task = service.create(draft);
    http.expectOne('/api/equipment').flush({ code: 'client-not-found' }, { status: 400, statusText: 'Bad Request' });
    expect(await task).toBe('client-not-found'); expect(service.equipment()).toEqual([]);
  });
  it('preserves the original equipment on a duplicate series error', async () => {
    TestBed.inject(ApiStore).equipment.set([{ ...draft, id: 'equipment-1' }]);
    const task = service.update('equipment-1', { ...draft, serialNumber: 'other' });
    http.expectOne('/api/equipment/equipment-1').flush({ code: 'duplicate-serial' }, { status: 409, statusText: 'Conflict' });
    expect(await task).toBe('duplicate-serial'); expect(service.findById('equipment-1')?.serialNumber).toBe('SN-1');
  });
});
