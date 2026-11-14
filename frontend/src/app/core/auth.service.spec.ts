import { TestBed } from '@angular/core/testing';
import { HttpTestingController } from '@angular/common/http/testing';
import { AuthService } from './auth.service';
import { ApiStore } from './api.store';
import { admin, configureApi, initialize, snapshot } from './api-test.helpers';

describe('Server authentication', () => {
  let http: HttpTestingController;
  let service: AuthService;
  beforeEach(() => { http = configureApi(); service = TestBed.inject(AuthService); });
  afterEach(() => http.verify());
  it('logs in through the API and loads only server data', async () => {
    const task = service.signIn('admin', 'password-test');
    const request = http.expectOne('/api/auth/login');
    expect(request.request.body).toEqual({ username: 'admin', password: 'password-test' });
    request.flush(admin); await Promise.resolve(); await Promise.resolve();
    http.expectOne('/api/bootstrap').flush(snapshot());
    expect(await task).toBe('success'); expect(service.currentUser()?.id).toBe('admin-1');
    expect((service.currentUser() as unknown as Record<string, unknown>)['password']).toBeUndefined();
  });
  it('restores the server session on application initialization', async () => {
    await initialize(http); expect(service.hasSession()).toBeTrue();
  });
  it('does not accept browser-only credentials on a server error', async () => {
    const task = service.signIn('admin', 'incorrect');
    http.expectOne('/api/auth/login').flush({ code: 'invalid-credentials' }, { status: 401, statusText: 'Unauthorized' });
    expect(await task).toBe('invalid-credentials'); expect(service.hasSession()).toBeFalse();
  });
  it('does not report logout success when the server could not invalidate the session', async () => {
    await initialize(http);
    const task = service.signOut();
    http.expectOne('/api/auth/logout').flush({}, { status: 500, statusText: 'Error' });
    expect(await task).toBeFalse(); expect(service.hasSession()).toBeTrue();
  });
  it('clears all data after a successful logout', async () => {
    await initialize(http);
    const task = service.signOut(); http.expectOne('/api/auth/logout').flush(null);
    expect(await task).toBeTrue(); expect(TestBed.inject(ApiStore).users()).toEqual([]);
  });
});
