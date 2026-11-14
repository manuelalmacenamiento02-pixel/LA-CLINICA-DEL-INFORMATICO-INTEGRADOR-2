import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { OrdersComponent } from './orders.component';

describe('OrdersComponent', () => {
  let fixture: ComponentFixture<OrdersComponent>;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [OrdersComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    });
    http = TestBed.inject(HttpTestingController);
    const store = TestBed.inject(ApiStore);
    store.user.set({
      id: 'staff-1',
      firstName: 'Ana',
      lastName: 'Atención',
      username: 'ana',
      role: 'PERSONAL DE ATENCIÓN',
      active: true,
    });
    store.permissions.update((permissions) => ({
      ...permissions,
      'PERSONAL DE ATENCIÓN': ['orders', 'assign-technicians'],
    }));
    store.clients.set([
      {
        id: 'client-1',
        documentType: 'DNI',
        documentNumber: '87654321',
        firstName: 'Ángela María',
        lastName: 'Núñez Pérez',
        phone: '987123456',
        email: 'angela@example.com',
        address: '',
        observations: '',
      },
      {
        id: 'client-2',
        documentType: 'DNI',
        documentNumber: '12345678',
        firstName: 'Carlos',
        lastName: 'Ruiz',
        phone: '987654321',
        email: 'carlos@example.com',
        address: '',
        observations: '',
      },
    ]);
    fixture = TestBed.createComponent(OrdersComponent);
    fixture.detectChanges();
    http.expectOne('/api/orders').flush([{
      id: 'order-1',
      code: 'OS-1',
      orderNumber: 1,
      receivedDate: '2026-11-14',
      createdAt: '2026-11-14T12:00:00Z',
      status: 'PENDIENTE',
      priority: 'MEDIA',
      reportedProblem: 'No enciende',
      initialObservations: '',
      clientId: 'client-1',
      clientName: 'Ángela María Núñez Pérez',
      clientDocument: '87654321',
      clientPhone: '987123456',
      equipmentId: 'equipment-1',
      equipmentType: 'Laptop',
      brand: 'Marca',
      model: 'Modelo',
      serialNumber: 'serie-1',
      equipmentCharacteristics: '',
      technicianId: null,
      technicianName: null,
    }]);
    fixture.detectChanges();
  });

  afterEach(() => http.verify());

  function openCreateForm(): void {
    const button = (fixture.nativeElement as HTMLElement).querySelector<HTMLButtonElement>(
      '.module-new-button',
    );
    if (!button) throw new Error('New order button was not rendered.');
    button.click();
    fixture.detectChanges();
  }

  function searchClients(value: string): HTMLSelectElement {
    const input = (fixture.nativeElement as HTMLElement)
      .querySelector<HTMLInputElement>('#order-client-search');
    if (!input) throw new Error('Client search input was not rendered.');
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    const select = (fixture.nativeElement as HTMLElement).querySelector<HTMLSelectElement>(
      '#order-client',
    );
    if (!select) throw new Error('Client selector was not rendered.');
    return select;
  }

  it('lets service staff open technician assignment', () => {
    const assignmentButton = Array.from(
      (fixture.nativeElement as HTMLElement).querySelectorAll<HTMLButtonElement>('.module-actions button'),
    ).find((button) => button.textContent?.includes('Asignar técnico'));
    expect(assignmentButton).not.toBeNull();
  });

  it('filters clients by accented name without regard to accents or spaces', () => {
    openCreateForm();

    const select = searchClients(' angela   nunez ');

    expect(Array.from(select.options).map((option) => option.textContent?.trim()))
      .toEqual(['Selecciona un cliente', 'Ángela María Núñez Pérez — 87654321']);
  });

  it('filters clients by DNI', () => {
    openCreateForm();

    const select = searchClients('12345678');

    expect(Array.from(select.options).map((option) => option.textContent?.trim()))
      .toEqual(['Selecciona un cliente', 'Carlos Ruiz — 12345678']);
  });
});
