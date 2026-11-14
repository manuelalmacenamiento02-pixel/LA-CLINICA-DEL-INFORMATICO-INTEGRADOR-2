import { Client } from './client.models';
import { Equipment } from './equipment.models';
import { OrderPriority, OrderStatus } from './service-order.models';

export interface ClientServiceOrder {
  id: string;
  code: string;
  receivedDate: string;
  status: OrderStatus;
  reportedProblem: string;
  equipmentId: string;
  equipmentType: string;
  brand: string;
  model: string;
}

export interface ClientDetail {
  client: Client;
  equipment: Equipment[];
  orders: ClientServiceOrder[];
}

export interface ServiceTimelineStep {
  code: string;
  label: string;
  occurredAt: string | null;
  completed: boolean;
}

export interface TrackingOrder {
  id: string;
  code: string;
  receivedDate: string;
  status: OrderStatus;
  clientName?: string;
  equipmentId: string;
  equipmentType: string;
  brand: string;
  model: string;
  technicianId: string | null;
  technicianName: string | null;
}

export interface EquipmentServiceRecord {
  id: string;
  code: string;
  receivedDate: string;
  createdAt: string;
  status: OrderStatus;
  priority: OrderPriority;
  reportedProblem: string;
  finalizedAt: string | null;
  technicianId: string | null;
  technicianName: string | null;
  diagnosis: string | null;
  actionsPerformed: string | null;
  performedTests: string | null;
  resultSummary: string | null;
  attentionFinishedAt: string | null;
  aiOriginalResponse: string | null;
  aiResult: string | null;
  aiValidation: 'ACEPTADO' | 'MODIFICADO' | 'DESCARTADO' | null;
  aiModifiedResult: string | null;
  aiValidationObservations: string | null;
  aiValidatedAt: string | null;
}

export interface EquipmentServiceHistory {
  equipment: Equipment & {
    clientDocument: string;
    ownerName: string;
  };
  orders: EquipmentServiceRecord[];
}

export interface TrackingDetail extends TrackingOrder {
  createdAt: string;
  priority: OrderPriority;
  reportedProblem: string;
  serialNumber: string;
  assignedAt: string | null;
  finalizedAt: string | null;
  diagnosis: string | null;
  actionsPerformed: string | null;
  performedTests: string | null;
  resultSummary: string | null;
  attentionFinishedAt: string | null;
  timeline: ServiceTimelineStep[];
  validatedPrediagnoses: {
    originalResponse: string;
    originalResult: string;
    decision: string;
    modifiedResult: string | null;
    observations: string;
    validatedAt: string;
    validatedBy: string;
  }[];
}

export interface PublicTrackingResult {
  code: string;
  equipmentType: string;
  receivedDate: string;
  status: OrderStatus;
  finalizedAt: string | null;
  timeline: ServiceTimelineStep[];
}
