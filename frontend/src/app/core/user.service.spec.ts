import { TestBed } from '@angular/core/testing';
import { HttpTestingController } from '@angular/common/http/testing';
import { UserService } from './user.service';
import { ApiStore } from './api.store';
import { admin, configureApi } from './api-test.helpers';

describe('User API persistence', () => {
  let http: HttpTestingController; let service: UserService;
  beforeEach(() => { http = configureApi(); service = TestBed.inject(UserService); });
  afterEach(() => http.verify());
  it('sends a password only to the create endpoint and retains the public response', async () => {
    const task = service.create({ ...admin, password: 'test-password' });
    const request = http.expectOne('/api/users'); expect(request.request.body.password).toBe('test-password');
    request.flush(admin); expect(await task).toBe('success');
    expect((service.users()[0] as unknown as Record<string, unknown>)['password']).toBeUndefined();
  });
  it('keeps the administrator active when the server blocks self-deactivation', async () => {
    TestBed.inject(ApiStore).users.set([admin]);
    const task = service.setActive(admin.id, false);
    http.expectOne('/api/users/admin-1/active').flush({ code: 'self-change' }, { status: 409, statusText: 'Conflict' });
    expect(await task).toBeFalse(); expect(service.findById(admin.id)?.active).toBeTrue();
  });
});
