import { TestBed } from '@angular/core/testing';
import { HttpTestingController } from '@angular/common/http/testing';
import { ClientService } from './client.service';
import { ApiStore } from './api.store';
import { configureApi } from './api-test.helpers';

const draft = { documentType: 'DNI' as const, documentNumber: '40123456', firstName: 'Elena', lastName: 'Vega', phone: '987123456', email: 'elena@example.com', address: '', observations: '' };
describe('Client API persistence', () => {
  let http: HttpTestingController; let service: ClientService;
  beforeEach(() => { http = configureApi(); service = TestBed.inject(ClientService); });
  afterEach(() => http.verify());
  it('waits for server confirmation before showing a new client', async () => {
    const task = service.create(draft); expect(service.clients()).toEqual([]);
    http.expectOne('/api/clients').flush({ ...draft, id: 'client-1' });
    expect(await task).toBe('success'); expect(service.findById('client-1')?.documentNumber).toBe('40123456');
  });
  it('preserves existing data when a concurrent duplicate is rejected by PostgreSQL', async () => {
    TestBed.inject(ApiStore).clients.set([{ ...draft, id: 'client-1' }]);
    const task = service.create(draft);
    http.expectOne('/api/clients').flush({ code: 'duplicate-document' }, { status: 409, statusText: 'Conflict' });
    expect(await task).toBe('duplicate-document'); expect(service.clients().length).toBe(1);
  });
  it('detects duplicate emails without regard to letter case', () => {
    TestBed.inject(ApiStore).clients.set([{ ...draft, id: 'client-1' }]);
    expect(service.isEmailInUse('ELENA@example.com')).toBeTrue();
    expect(service.isEmailInUse('elena@example.com', 'client-1')).toBeFalse();
  });
  it('preserves existing data when PostgreSQL rejects a duplicate email', async () => {
    TestBed.inject(ApiStore).clients.set([{ ...draft, id: 'client-1' }]);
    const task = service.create({ ...draft, documentNumber: '40123457' });
    http.expectOne('/api/clients').flush({ code: 'duplicate-email' }, { status: 409, statusText: 'Conflict' });
    expect(await task).toBe('duplicate-email');
    expect(service.clients().length).toBe(1);
  });
  it('keeps the client when deletion is blocked by related equipment', async () => {
    TestBed.inject(ApiStore).clients.set([{ ...draft, id: 'client-1' }]);
    const task = service.delete('client-1');
    http.expectOne('/api/clients/client-1').flush({ code: 'related-records' }, { status: 409, statusText: 'Conflict' });
    expect(await task).toBeFalse(); expect(service.findById('client-1')).toBeDefined();
  });
});
