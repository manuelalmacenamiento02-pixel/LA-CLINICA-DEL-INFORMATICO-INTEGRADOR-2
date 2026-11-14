import { provideHttpClient } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { By } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { NgModel } from '@angular/forms';
import { ApiStore } from '../../core/api.store';
import { ServiceOrderService } from '../../core/service-order.service';
import { PublicTrackingComponent } from './public-tracking.component';

describe('PublicTrackingComponent', () => {
  let fixture: ComponentFixture<PublicTrackingComponent>;
  let getPublicTracking: jasmine.Spy;

  beforeEach(() => {
    getPublicTracking = jasmine.createSpy('getPublicTracking');
    TestBed.configureTestingModule({
      imports: [PublicTrackingComponent],
      providers: [
        provideHttpClient(),
        provideRouter([]),
        { provide: ApiStore, useValue: { pending: signal(0) } },
        {
          provide: ServiceOrderService,
          useValue: { getPublicTracking },
        },
      ],
    });
    fixture = TestBed.createComponent(PublicTrackingComponent);
    fixture.detectChanges();
  });

  it('requires a valid order code and verification phone before calling the API', () => {
    const root = fixture.nativeElement as HTMLElement;
    const input = root.querySelector<HTMLInputElement>('#public-order-code');
    if (!input) throw new Error('Public order code input was not rendered.');
    input.value = '123';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    fixture.detectChanges();
    root.querySelector<HTMLFormElement>('form')?.dispatchEvent(
      new Event('submit', { bubbles: true, cancelable: true }),
    );
    fixture.detectChanges();

    expect(getPublicTracking).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Ingresa el código de orden');
    expect(fixture.nativeElement.textContent).toContain('El teléfono es obligatorio');
  });

  it('sends the verification values and renders only the public result', async () => {
    getPublicTracking.and.resolveTo({
      code: 'OS-000123',
      equipmentType: 'Laptop',
      receivedDate: '2026-10-17',
      status: 'EN_ATENCION',
      finalizedAt: null,
      timeline: [
        { code: 'ORDEN_REGISTRADA', label: 'Orden registrada', occurredAt: '2026-10-17', completed: true },
      ],
    });
    const root = fixture.nativeElement as HTMLElement;
    const codeModel = fixture.debugElement.query(By.css('#public-order-code')).injector.get(NgModel);
    const phoneModel = fixture.debugElement.query(By.css('#public-phone')).injector.get(NgModel);
    codeModel.viewToModelUpdate('OS-000123');
    phoneModel.viewToModelUpdate('987 654 321');
    fixture.detectChanges();
    root.querySelector<HTMLFormElement>('form')?.dispatchEvent(
      new Event('submit', { bubbles: true, cancelable: true }),
    );
    await fixture.whenStable();
    fixture.detectChanges();

    expect(getPublicTracking).toHaveBeenCalledWith('OS-000123', '987 654 321');
    const resultText = root.querySelector('.public-tracking-result')?.textContent;
    expect(resultText).toContain('OS-000123');
    expect(resultText).toContain('En atención');
    expect(resultText).not.toContain('diagnóstico');
    expect(resultText).not.toContain('cliente');
  });
});
