export const DOCUMENT_TYPES = ['DNI', 'RUC', 'CE', 'Otro'] as const;

export type DocumentType = (typeof DOCUMENT_TYPES)[number];

export interface Client {
  id: string;
  documentType: DocumentType;
  documentNumber: string;
  firstName: string;
  lastName: string;
  phone: string;
  email: string;
  address: string;
  observations: string;
}

export type ClientDraft = Omit<Client, 'id'>;
