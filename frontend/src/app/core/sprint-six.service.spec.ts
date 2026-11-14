import { HttpErrorResponse } from '@angular/common/http';
import { sprintSixErrorMessage } from './sprint-six.service';

describe('sprintSixErrorMessage', () => {
  it('explains when the backend cannot be reached', () => {
    expect(sprintSixErrorMessage(new HttpErrorResponse({ status: 0 })))
      .toContain('No se pudo contactar al backend');
  });

  it('identifies missing module permission', () => {
    expect(sprintSixErrorMessage(new HttpErrorResponse({ status: 403 })))
      .toContain('no tiene permiso');
  });

  it('preserves the backend error message', () => {
    expect(sprintSixErrorMessage(new HttpErrorResponse({
      status: 500,
      error: { message: 'Error de consulta' },
    }))).toBe('Error de consulta');
  });

  it('points to backend logs when an internal error has no message', () => {
    expect(sprintSixErrorMessage(new HttpErrorResponse({ status: 500 })))
      .toContain('Revisa la consola');
  });
});
