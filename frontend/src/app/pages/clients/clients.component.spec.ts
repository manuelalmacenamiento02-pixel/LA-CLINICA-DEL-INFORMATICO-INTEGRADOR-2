import { provideHttpClient } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ApiStore } from '../../core/api.store';
import { ClientsComponent } from './clients.component';

describe('ClientsComponent search', () => {
  let fixture: ComponentFixture<ClientsComponent>;
  let store: ApiStore;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ClientsComponent],
      providers: [provideHttpClient()],
    });
    store = TestBed.inject(ApiStore);
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
    fixture = TestBed.createComponent(ClientsComponent);
    fixture.detectChanges();
  });

  function search(value: string): void {
    const input = (fixture.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#search-client');
    if (!input) throw new Error('Client search input was not rendered.');
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('finds clients by first name and surname, ignoring accents and extra spaces', () => {
    search('  angela   Nunez  ');

    const rows = fixture.nativeElement.querySelectorAll('tbody tr');
    expect(rows.length).toBe(1);
    expect(rows[0].textContent).toContain('Ángela María Núñez Pérez');
  });

  it('finds clients by document number', () => {
    search('87654321');

    const rows = fixture.nativeElement.querySelectorAll('tbody tr');
    expect(rows.length).toBe(1);
    expect(rows[0].textContent).toContain('Ángela María Núñez Pérez');
  });
});
