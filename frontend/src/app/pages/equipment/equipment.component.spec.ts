import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { EquipmentComponent } from './equipment.component';

describe('EquipmentComponent client search', () => {
  let fixture: ComponentFixture<EquipmentComponent>;
  let http: HttpTestingController;

  beforeEach(async () => {
    TestBed.configureTestingModule({
      imports: [EquipmentComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    });

    http = TestBed.inject(HttpTestingController);
    TestBed.inject(ApiStore).clients.set([
      {
        id: 'client-1',
        documentType: 'DNI',
        documentNumber: '87654321',
        firstName: 'Ana María',
        lastName: 'López Núñez',
        phone: '987123456',
        email: 'ana@example.com',
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

    fixture = TestBed.createComponent(EquipmentComponent);
    fixture.detectChanges();
    (fixture.nativeElement as HTMLElement)
      .querySelector<HTMLButtonElement>('.module-new-button')
      ?.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  });

  afterEach(() => http.verify());

  function search(value: string): void {
    const input = (fixture.nativeElement as HTMLElement)
      .querySelector<HTMLInputElement>('#equipment-client-search');
    if (!input) throw new Error('Equipment client search input was not rendered.');
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  function clientResults(): HTMLButtonElement[] {
    return Array.from(
      (fixture.nativeElement as HTMLElement).querySelectorAll<HTMLButtonElement>('.client-search-result'),
    );
  }

  it('does not show every registered client before a search is entered', () => {
    expect(clientResults()).toEqual([]);
    expect((fixture.nativeElement as HTMLElement).textContent).toContain(
      'Escribe para buscar entre los clientes registrados.',
    );
  });

  it('shows a client when name and surname tokens are separated and accented', () => {
    search('  maria   nunez ');

    expect(clientResults().length).toBe(1);
    expect(clientResults()[0].textContent).toContain('Ana María López Núñez');
  });

  it('keeps the selected client associated when the search is cleared', () => {
    search('maria nunez');
    clientResults()[0].click();
    fixture.detectChanges();

    search('');

    expect(clientResults()).toEqual([]);
    expect((fixture.nativeElement as HTMLElement).textContent).toContain(
      'Cliente asociado: Ana María López Núñez',
    );
  });

  it('searches client document, phone, and email fields', () => {
    search('carlos@example.com');

    expect(clientResults().length).toBe(1);
    expect(clientResults()[0].textContent).toContain('Carlos Ruiz');
  });

  it('associates the visible client result and submits its id with the equipment', async () => {
    search('maria nunez');
    clientResults()[0].click();
    fixture.detectChanges();

    expect((fixture.nativeElement as HTMLElement).textContent).toContain(
      'Cliente asociado: Ana María López Núñez',
    );

    const root = fixture.nativeElement as HTMLElement;
    for (const [selector, value] of [
      ['#equipment-brand', 'Lenovo'],
      ['#equipment-model', 'ThinkPad'],
      ['#equipment-serial', 'SN-123'],
    ]) {
      const input = root.querySelector<HTMLInputElement>(selector);
      if (!input) throw new Error(`Expected equipment field ${selector} was not rendered.`);
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }
    await fixture.whenStable();
    fixture.detectChanges();

    const submit = root.querySelector<HTMLButtonElement>('button[type="submit"]');
    if (!submit) throw new Error('Equipment submit button was not rendered.');
    submit.click();
    fixture.detectChanges();
    const request = http.expectOne('/api/equipment');
    expect(request.request.body.clientId).toBe('client-1');
    request.flush({
      id: 'equipment-1',
      clientId: 'client-1',
      type: 'Laptop',
      brand: 'Lenovo',
      model: 'ThinkPad',
      serialNumber: 'SN-123',
      characteristics: '',
      accessories: '',
      observations: '',
    });
    await fixture.whenStable();
    fixture.detectChanges();

    expect(root.textContent).toContain('Equipo registrado correctamente.');
  });
});
