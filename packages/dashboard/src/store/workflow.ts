import { create } from 'zustand';

interface WorkflowStore {
  selectedWorkflowId: bigint | null;
  setSelectedWorkflowId: (id: bigint | null) => void;
}

export const useWorkflowStore = create<WorkflowStore>((set) => ({
  selectedWorkflowId: null,
  setSelectedWorkflowId: (id) => set({ selectedWorkflowId: id }),
}));
