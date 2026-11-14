import { TestBed } from '@angular/core/testing';
import { HttpTestingController } from '@angular/common/http/testing';
import { PermissionsService } from './permissions.service';
import { ApiStore } from './api.store';
import { configureApi, initialize, snapshot } from './api-test.helpers';

describe('Server permissions', () => {
  let http: HttpTestingController; let service: PermissionsService;
  beforeEach(() => { http = configureApi(); service = TestBed.inject(PermissionsService); });
  afterEach(() => http.verify());
  it('starts without privileges before the server session is loaded', () => {
    expect(service.can('ADMINISTRADOR', 'users')).toBeFalse();
  });
  it('uses server permissions and waits for confirmation before changing them', async () => {
    await initialize(http);
    const task = service.update('TÉCNICO', 'clients', true);
    expect(service.can('TÉCNICO', 'clients')).toBeFalse();
    const next = snapshot().permissions; next.TÉCNICO = ['dashboard', 'clients'];
    http.expectOne('/api/permissions').flush(next);
    expect(await task).toBeTrue(); expect(service.can('TÉCNICO', 'clients')).toBeTrue();
  });
  it('does not change protected permissions on a rejected update', async () => {
    await initialize(http);
    const before = TestBed.inject(ApiStore).permissions();
    const task = service.update('TÉCNICO', 'users', true);
    http.expectOne('/api/permissions').flush({ code: 'protected-permission' }, { status: 400, statusText: 'Bad Request' });
    expect(await task).toBeFalse(); expect(TestBed.inject(ApiStore).permissions()).toEqual(before);
  });
});
